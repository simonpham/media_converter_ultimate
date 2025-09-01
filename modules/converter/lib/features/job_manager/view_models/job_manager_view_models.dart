import 'dart:async';

import 'package:converter/converter.dart';
import 'package:core/core.dart';
import 'package:core_storage_base/data/data.dart';
import 'package:flutter/foundation.dart';
import 'package:platform_utils/platform_utils.dart';
import 'package:utils/utils.dart';

class JobManagerViewModel extends ChangeNotifier {
  final JobRunnerService _jobRunnerService;

  ConvertJobStorage get _jobStorage => ConvertJobStorage.getInstance();

  JobManagerViewModel(this._jobRunnerService) {
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

  Future<void> addJobs(final List<ConvertJob> jobs) async {
    await _jobStorage.addAll(jobs);
    await _runPendingJobs(jobs);
  }

  Future<void> removeRunningJob(ConvertJob job) async {
    final sessionId = job.sessionId;
    if (sessionId == null) {
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
      return;
    }

    if (updatedJob.status != JobStatus.cleaning) {
      return;
    }

    final failure = await _completeJob(updatedJob);
    if (failure != null) {
      final failedJob = updatedJob.copyWith(
        status: const Some(JobStatus.actionRequired),
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
  }

  Future<void> _cleanFailedJob(ConvertJob job) async {
    if (!job.status.isFailure) {
      return;
    }

    await FileUtils.cleanUpTempFile(
      fileName: job.outputFileName,
      path: job.outputDirectoryPath,
    );
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
    final success = await FileUtils.moveTempFileToPath(
      fileName: job.outputFileName,
      path: job.outputDirectoryPath,
    );
    if (!success) {
      return DirectoryNotWritableFailure(job.outputDirectoryPath);
    }

    return null;
  }

  Future<void> _runPendingJobs(List<ConvertJob> pendingJobs) async {
    for (final job in pendingJobs) {
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

    job.clearLog();
    await _jobStorage.delete(job.id);
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
}
