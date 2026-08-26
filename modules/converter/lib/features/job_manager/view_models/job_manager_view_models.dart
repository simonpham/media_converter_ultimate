import 'dart:async';

import 'package:converter/converter.dart';
import 'package:core_storage_base/data/data.dart';
import 'package:flutter/foundation.dart';
import 'package:platform_utils/platform_utils.dart';
import 'package:utils/utils.dart';

class JobManagerViewModel extends ChangeNotifier {
  FileService get _fileService => injector<FileService>();

  JobRunnerService get _jobRunnerService => injector<JobRunnerService>();

  ConvertJobStorage get _jobStorage => ConvertJobStorage.getInstance();

  JobManagerViewModel() {
    _jobSubscription = _jobRunnerService.onJobUpdate.listen(
      _handleJobUpdate,
    );

    _logSubscription = _jobRunnerService.onLogUpdate.listen(
      _handleLogUpdate,
    );
  }

  StreamSubscription? _jobSubscription;
  StreamSubscription? _logSubscription;

  Stream<List<ConvertJob>> get pendingJobsStream =>
      _jobStorage.watchPendingJobs();
  Stream<List<ConvertJob>> get runningJobsStream =>
      _jobStorage.watchRunningJobs();
  Stream<List<ConvertJob>> get completedJobsStream =>
      _jobStorage.watchCompletedJobs();
  Stream<List<ConvertJob>> get actionRequiredJobsStream =>
      _jobStorage.watchActionRequiredJobs();

  @override
  void dispose() {
    _jobSubscription?.cancel();
    _logSubscription?.cancel();
    super.dispose();
  }

  Future<void> addJobs(List<ConvertJob> jobs) async {
    await _jobStorage.addAll(jobs);
    await _runPendingJobs();
  }

  Future<void> removeRunningJob(ConvertJob job) async {
    final sessionId = job.sessionId;
    if (sessionId == null) {
      printLog('[JobManagerViewModel]: Session id is null');
      return;
    }

    await _jobRunnerService.stop(job);
  }

  Future<void> runJob(ConvertJob job) async {
    await _jobRunnerService.run(job);
  }

  Future<void> restartJob(ConvertJob job) async {
    final newJob = job.copyWith(
      status: const Some(JobStatus.pending),
    );
    await _jobStorage.update(newJob);
    await _jobRunnerService.run(newJob);
  }

  Future<void> _handleJobUpdate(ConvertJob job) async {
    final updatedJob = await _updateJobInList(job);

    if (updatedJob.status.isFailure) {
      await _cleanFailedJob(updatedJob);
      await _runPendingJobs();
      return;
    }

    if (updatedJob.status != JobStatus.cleaning) {
      return;
    }

    final failure = await _completeJob(updatedJob);
    if (failure != null) {
      final (
        newPath,
        copyFailure,
      ) = await _fileService.copyTempOutputFileToConverted(
        jobId: job.id,
        convertedFilePath: job.convertedFilePath,
      );

      if (newPath == null || copyFailure != null) {
        // Hết cứu.
        final failedJob = updatedJob.copyWith(
          status: const Some(JobStatus.failed),
        );
        await _handleJobUpdate(failedJob);
        LogData().appendLog(failedJob.id, failure.toString());
        return;
      }

      final failedJob = updatedJob.copyWith(
        status: const Some(JobStatus.actionRequired),
        convertedFilePath: Some(newPath),
      );
      await _handleJobUpdate(failedJob);
      LogData().appendLog(failedJob.id, failure.toString());
      return;
    }

    await _handleJobUpdate(
      updatedJob.copyWith(
        status: const Some(JobStatus.completed),
      ),
    );
    await injector<FileService>().cleanUpInputFile(jobId: updatedJob.id);
    await _fileService.cleanUpInputFile(jobId: updatedJob.id);
    SettingsBox().successConversionCount++;
    printLog(
      '[AdsSettings] successConversionCount increased: ${SettingsBox().successConversionCount}',
    );
    await _runPendingJobs();
  }

  Future<void> _cleanFailedJob(ConvertJob job) async {
    if (!job.status.isFailure) {
      return;
    }

    await injector<FileService>().prepareConvertTempFolder(jobId: job.id);
  }

  void _handleLogUpdate(JobLog event) {
    final jobId = event.jobId;
    final message = event.message;
    printLog('[JobManagerViewModel]: Log: $message');
    LogData().appendLog(jobId, message);
  }

  Future<ConvertJob> _updateJobInList(ConvertJob job) async {
    final currentJob = await _jobStorage.get(job.id);
    if (currentJob != null && currentJob.status.isDone) {
      job = job.copyWith(
        status: Some(currentJob.status),
      );
    }

    await _jobStorage.update(job);
    return job;
  }

  Future<Failure?> _completeJob(ConvertJob job) async {
    if (job.status != JobStatus.cleaning) {
      return const InvalidStatusFailure();
    }

    // Move completed job to output directory.
    final failure = await _fileService.moveConvertedFileToPath(
      convertedFilePath: job.convertedFilePath,
      outputFileName: job.outputFileName,
      outputFilePath: job.outputDirectoryPath,
    );
    if (failure != null) {
      return failure;
    }

    return null;
  }

  Future<void> _runPendingJobs() async {
    final concurrencyLimit = SettingsBox().concurrencyLimit;
    final runningJobs = await _jobStorage.getAllRunningJobs();
    final currentRunningCount = runningJobs.length;
    final availableSlots = concurrencyLimit - currentRunningCount;

    if (availableSlots <= 0) {
      return;
    }

    final pendingJobs = await _jobStorage.getAllPendingJobs();
    final jobsToStart = pendingJobs.take(availableSlots).toList();

    for (final job in jobsToStart) {
      await runJob(job);
    }
  }

  Future<Failure?> deleteOutputFile(ConvertJob job) async {
    if (job.status.isProcessing) {
      // Not allowed to remove running job.
      return const InvalidStatusFailure();
    }

    final outputFile = job.outputFile;
    try {
      printLog(
        '[JobManagerViewModel]: Removing output file: ${outputFile.path}',
      );
      await outputFile.delete();
    } catch (err, trace) {
      printError(err, trace);
      LogData().appendLog(job.id, err.toString());
      return FileDeleteFailure(outputFile.path);
    }

    return null;
  }

  Future<Failure?> removeJob(ConvertJob job) async {
    if (job.status.isProcessing) {
      // Not allowed to remove running job.
      return const InvalidStatusFailure();
    }

    final jobId = job.id;
    final convertedFilePath = job.convertedFilePath;

    job.clearLog();
    await _jobStorage.delete(jobId);

    await _fileService.cleanUpInputFile(jobId: jobId);
    await _fileService.deleteFileAtPath(convertedFilePath);
    return null;
  }

  Future<Failure?> clearFinishedJobs(ClearFinishedJobsOption result) async {
    final success = switch (result) {
      ClearFinishedJobsOption.everything =>
        await _jobStorage.removeAllFinishedJobs(),
      _ => await _jobStorage.removeOlderFinishedJobs(result.dayCount),
    };

    if (!success) {
      return const FailedToClearJobsFailure();
    }

    return null;
  }

  Future<Failure?> handleJobRenameAction(
    ConvertJob job,
    String newName,
  ) async {
    if (job.status != JobStatus.actionRequired) {
      return const InvalidStatusFailure();
    }

    final newJob = job.copyWith(
      outputFileName: Some(newName),
      status: const Some(JobStatus.cleaning),
    );

    if (await isOutputFileExists(newJob)) {
      return OutputFileAlreadyExistsFailure(newJob.outputFile.path);
    }

    await _handleJobUpdate(newJob);
    return null;
  }

  Future<Failure?> handleJobChooseAnotherPathAction(
    ConvertJob job,
    String newPath,
  ) async {
    if (job.status != JobStatus.actionRequired) {
      return const InvalidStatusFailure();
    }

    final newJob = job.copyWith(
      outputDirectoryPath: Some(newPath),
      status: const Some(JobStatus.cleaning),
    );

    if (await isOutputFileExists(newJob)) {
      return OutputFileAlreadyExistsFailure(newJob.outputFile.path);
    }

    await _handleJobUpdate(newJob);
    return null;
  }

  Future<bool> isOutputFileExists(ConvertJob job) async {
    try {
      final file = job.outputFile;
      return await file.exists();
    } catch (err, trace) {
      printError(err, trace);
      LogData().appendLog(job.id, err.toString());
      return false;
    }
  }

  Future<void> restartPendingJobs() async {
    await _jobStorage.fixInvalidJobs();
    await _runPendingJobs();
  }
}
