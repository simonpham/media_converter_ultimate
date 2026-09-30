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
      (job) => unawaited(_queueJobUpdate(job)),
    );

    _logSubscription = _jobRunnerService.onLogUpdate.listen(
      _handleLogUpdate,
    );
  }

  StreamSubscription? _jobSubscription;
  StreamSubscription? _logSubscription;
  final _jobOperations = <String, Future<void>>{};
  final _startingJobs = <String>{};
  final _retiredSessions = <String, Set<int>>{};
  Future<void>? _pendingRun;
  bool _shouldRescanQueue = false;
  bool _isDisposed = false;

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
    _isDisposed = true;
    final jobSubscription = _jobSubscription;
    final logSubscription = _logSubscription;
    if (jobSubscription != null) {
      unawaited(jobSubscription.cancel());
    }
    if (logSubscription != null) {
      unawaited(logSubscription.cancel());
    }
    super.dispose();
  }

  Future<void> addJobs(List<ConvertJob> jobs) async {
    final failure = await _jobStorage.addAll(jobs);
    if (failure != null) {
      throw failure;
    }
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
    if (_isDisposed || !_startingJobs.add(job.id)) {
      return;
    }
    try {
      final currentJob = await _jobStorage.get(job.id);
      if (currentJob == null || !currentJob.status.isQueued) {
        return;
      }
      final preparingJob = currentJob.copyWith(status: const Some(.preparing));
      final failure = await _jobStorage.update(preparingJob);
      if (failure != null) {
        throw failure;
      }
      try {
        final startedJob = await _jobRunnerService.run(preparingJob);
        await _queueJobUpdate(startedJob);
      } catch (err, trace) {
        printError(err, trace);
        LogData().appendLog(job.id, err.toString());
        await _queueJobUpdate(
          preparingJob.copyWith(status: const Some(.failed)),
        );
      }
    } finally {
      _startingJobs.remove(job.id);
    }
  }

  Future<void> restartJob(ConvertJob job) async {
    final currentJob = await _jobStorage.get(job.id);
    if (currentJob == null || !currentJob.status.isDone) {
      return;
    }
    final sessionId = currentJob.sessionId;
    if (sessionId != null) {
      (_retiredSessions[job.id] ??= {}).add(sessionId);
    }
    final newJob = currentJob.copyWith(
      status: const Some(.pending),
      sessionId: const Some(null),
      progress: const Some(null),
      duration: const Some(null),
    );
    await _jobStorage.update(newJob);
    await _runPendingJobs();
  }

  Future<void> _queueJobUpdate(ConvertJob job, {bool recoverOutput = false}) {
    final previous = _jobOperations[job.id] ?? Future<void>.value();
    final operation = previous.then((_) async {
      if (_isDisposed) {
        return;
      }
      try {
        await _handleJobUpdate(job, recoverOutput: recoverOutput);
      } catch (err, trace) {
        printError(err, trace);
        LogData().appendLog(job.id, err.toString());
      }
    });
    _jobOperations[job.id] = operation;
    unawaited(
      operation.then((_) {
        if (identical(_jobOperations[job.id], operation)) {
          _jobOperations.remove(job.id);
        }
      }),
    );
    return operation;
  }

  Future<void> _handleJobUpdate(
    ConvertJob job, {
    bool recoverOutput = false,
  }) async {
    if (_retiredSessions[job.id]?.contains(job.sessionId) == true) {
      return;
    }
    final currentJob = await _jobStorage.get(job.id);
    if (currentJob == null || currentJob.status.isDone) {
      return;
    }
    if (currentJob.status == .actionRequired && !recoverOutput) {
      return;
    }
    if (currentJob.status.isProcessing &&
        job.status.isProcessing &&
        job.status.index < currentJob.status.index) {
      return;
    }
    if (currentJob.sessionId != null &&
        job.sessionId != null &&
        currentJob.sessionId != job.sessionId) {
      return;
    }
    await _jobStorage.update(job);
    final updatedJob = job;

    if (updatedJob.status.isFailure) {
      try {
        await _cleanFailedJob(updatedJob);
      } finally {
        _requestPendingJobs();
      }
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
        final failedJob = updatedJob.copyWith(
          status: const Some(JobStatus.failed),
        );
        await _jobStorage.update(failedJob);
        LogData().appendLog(failedJob.id, failure.toString());
        _requestPendingJobs();
        return;
      }

      final recoveryJob = updatedJob.copyWith(
        status: const Some(JobStatus.actionRequired),
        convertedFilePath: Some(newPath),
      );
      await _jobStorage.update(recoveryJob);
      LogData().appendLog(recoveryJob.id, failure.toString());
      _requestPendingJobs();
      return;
    }

    await _jobStorage.update(
      updatedJob.copyWith(
        status: const Some(JobStatus.completed),
      ),
    );
    SettingsBox().successConversionCount++;
    printLog(
      '[AdsSettings] successConversionCount increased: ${SettingsBox().successConversionCount}',
    );
    try {
      await _fileService.cleanUpInputFile(jobId: updatedJob.id);
    } finally {
      _requestPendingJobs();
    }
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

  Future<void> _runPendingJobs() {
    _shouldRescanQueue = true;
    return _pendingRun ??= _drainPendingJobs().whenComplete(() {
      _pendingRun = null;
    });
  }

  void _requestPendingJobs() {
    unawaited(
      _runPendingJobs().catchError((Object err, StackTrace trace) {
        printError(err, trace);
      }),
    );
  }

  Future<void> _drainPendingJobs() async {
    while (_shouldRescanQueue && !_isDisposed) {
      _shouldRescanQueue = false;
      final concurrencyLimit = SettingsBox().concurrencyLimit;
      final runningJobs = await _jobStorage.getAllRunningJobs();
      final availableSlots = concurrencyLimit - runningJobs.length;
      if (availableSlots <= 0) {
        continue;
      }
      final pendingJobs = await _jobStorage.getAllPendingJobs();
      for (final job in pendingJobs.take(availableSlots)) {
        if (_isDisposed) {
          return;
        }
        await runJob(job);
      }
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
    final currentJob = await _jobStorage.get(job.id);
    if (currentJob == null) {
      return null;
    }
    if (currentJob.status.isProcessing) {
      // Not allowed to remove running job.
      return const InvalidStatusFailure();
    }

    final jobId = job.id;
    final convertedFilePath = currentJob.convertedFilePath;

    job.clearLog();
    await _jobStorage.delete(jobId);
    _retiredSessions.remove(jobId);

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

    await _queueJobUpdate(newJob, recoverOutput: true);
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

    await _queueJobUpdate(newJob, recoverOutput: true);
    return null;
  }

  Future<bool> isOutputFileExists(ConvertJob job) async {
    try {
      return await _fileService.isFileExist(job.outputFile.path);
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
