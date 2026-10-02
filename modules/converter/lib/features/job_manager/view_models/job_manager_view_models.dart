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
  final _exportFailures = <String, Failure>{};
  final _startingJobs = <String>{};
  final _activeExecutions = <String, String>{};
  final _stopRequests = <String, Future<void>>{};
  final _runnerStarts = <String, Completer<void>>{};

  String? activeExecutionId(String jobId) => _activeExecutions[jobId];
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

  Future<void> removeRunningJob(ConvertJob job, {String? executionId}) async {
    final currentJob = await _jobStorage.get(job.id);
    final active = _activeExecutions[job.id];
    final requested = executionId ?? job.executionId;
    if (currentJob == null ||
        !currentJob.status.isProcessing ||
        currentJob.status == .cleaning ||
        (job.sessionId != null && currentJob.sessionId != job.sessionId) ||
        (requested != null && requested != active) ||
        (job.sessionId == null && (requested == null || requested != active))) {
      return;
    }
    final key = '${job.id}:${active ?? job.sessionId}';
    final existing = _stopRequests[key];
    if (existing != null) return existing;
    if (currentJob.status == .stopping) return;
    final execution = currentJob.copyWith(executionId: Some(active));
    final operation = _stopExecution(execution).whenComplete(() {
      _stopRequests.remove(key);
    });
    _stopRequests[key] = operation;
    await operation;
  }

  Future<void> _stopExecution(ConvertJob job) async {
    await _queueJobUpdate(job.copyWith(status: const Some(.stopping)));
    var acknowledged = false;
    try {
      await _runnerStarts[job.executionId]?.future;
      acknowledged = await _jobRunnerService.stop(job);
    } catch (err, trace) {
      printError(err, trace);
      LogData().appendLog(job.id, err.toString());
    }
    // Drain native completion events before deciding whether to restore Stop.
    await _jobOperations[job.id];
    final current = await _jobStorage.get(job.id);
    if (current?.status != .stopping ||
        (job.executionId != null &&
            _activeExecutions[job.id] != job.executionId)) {
      return;
    }
    await _queueJobUpdate(
      current!.copyWith(
        executionId: Some(job.executionId),
        status: Some(
          acknowledged
              ? .cancelled
              : job.sessionId == null && current.sessionId != null
              ? .running
              : job.status,
        ),
      ),
      restoreAfterStop: !acknowledged,
    );
  }

  Future<void> runJob(ConvertJob job) async {
    if (_isDisposed || !_startingJobs.add(job.id)) {
      return;
    }
    Completer<void>? registered;
    String? executionId;
    try {
      final currentJob = await _jobStorage.get(job.id);
      if (currentJob == null || !currentJob.status.isQueued) {
        return;
      }
      executionId = kUuid.v4();
      registered = Completer<void>();
      _runnerStarts[executionId] = registered;
      _activeExecutions[job.id] = executionId;
      final preparingJob = currentJob.copyWith(
        status: const Some(.preparing),
        executionId: Some(executionId),
      );
      final failure = await _jobStorage.update(preparingJob);
      if (failure != null) {
        throw failure;
      }
      try {
        late final Future<ConvertJob> running;
        try {
          running = _jobRunnerService.run(preparingJob);
        } finally {
          registered.complete();
        }
        final startedJob = await running;
        await _queueJobUpdate(startedJob);
      } catch (err, trace) {
        printError(err, trace);
        LogData().appendLog(job.id, err.toString());
        await _queueJobUpdate(
          preparingJob.copyWith(status: const Some(.failed)),
        );
      }
    } finally {
      final didRegister = registered?.isCompleted ?? false;
      if (!didRegister && _activeExecutions[job.id] == executionId) {
        _activeExecutions.remove(job.id);
      }
      if (registered != null && !registered.isCompleted) registered.complete();
      _runnerStarts.remove(executionId);
      _startingJobs.remove(job.id);
      if (didRegister) _requestPendingJobs();
    }
  }

  Future<void> restartJob(ConvertJob job) async {
    await _jobOperations[job.id];
    final currentJob = await _jobStorage.get(job.id);
    if (currentJob == null || !currentJob.status.isDone) {
      return;
    }
    final sessionId = currentJob.sessionId;
    if (sessionId != null) {
      (_retiredSessions[job.id] ??= {}).add(sessionId);
    }
    await _fileService.acknowledgeExport(currentJob.id);
    final newJob = currentJob.copyWith(
      status: const Some(.pending),
      outputUri: const Some(null),
      outputStaged: const Some(false),
      sessionId: const Some(null),
      progress: const Some(null),
      duration: const Some(null),
    );
    await _jobStorage.update(newJob);
    await _runPendingJobs();
  }

  Future<void> _queueJobUpdate(
    ConvertJob job, {
    bool recoverOutput = false,
    bool restoreAfterStop = false,
  }) {
    final previous = _jobOperations[job.id] ?? Future<void>.value();
    final operation = previous.then((_) async {
      if (_isDisposed) {
        return;
      }
      try {
        await _handleJobUpdate(
          job,
          recoverOutput: recoverOutput,
          restoreAfterStop: restoreAfterStop,
        );
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
    bool restoreAfterStop = false,
  }) async {
    if (!recoverOutput &&
        job.executionId != null &&
        _activeExecutions[job.id] != job.executionId) {
      return;
    }
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
    if (currentJob.sessionId != null &&
        job.sessionId != null &&
        currentJob.sessionId != job.sessionId) {
      return;
    }
    if (currentJob.status == .stopping &&
        job.status.isProcessing &&
        job.status != .cleaning &&
        !restoreAfterStop) {
      // Keep real session/progress metadata if encoder startup won the race.
      await _jobStorage.update(
        currentJob.copyWith(
          sessionId: job.sessionId == null ? null : Some(job.sessionId),
          progress: job.progress == null ? null : Some(job.progress),
          duration: job.duration == null ? null : Some(job.duration),
        ),
      );
      return;
    }
    if (currentJob.status != .stopping &&
        currentJob.status.isProcessing &&
        job.status.isProcessing &&
        job.status.index < currentJob.status.index) {
      return;
    }
    final updateFailure = await _jobStorage.update(job);
    if (updateFailure != null) throw updateFailure;
    final updatedJob = job;

    if (updatedJob.status.isFailure) {
      try {
        await _cleanFailedJob(updatedJob);
      } finally {
        _finishExecution(updatedJob);
        _requestPendingJobs();
      }
      return;
    }

    if (updatedJob.status != JobStatus.cleaning) {
      return;
    }

    var finishing = updatedJob;
    if (!finishing.outputStaged) {
      final (savedPath, saveFailure) = await _fileService
          .copyTempOutputFileToConverted(
            jobId: finishing.id,
            convertedFilePath: finishing.convertedFilePath,
          );
      if (savedPath == null || saveFailure != null) {
        _exportFailures[finishing.id] =
            saveFailure ?? const OutputExportFailure();
        await _jobStorage.update(
          finishing.copyWith(status: const Some(.failed)),
        );
        LogData().appendLog(
          finishing.id,
          (saveFailure ?? const OutputExportFailure()).toString(),
        );
        _finishExecution(finishing);
        _requestPendingJobs();
        return;
      }
      finishing = finishing.copyWith(
        convertedFilePath: Some(savedPath),
        outputStaged: const Some(true),
      );
      final saveFailureResult = await _jobStorage.update(finishing);
      if (saveFailureResult != null) throw saveFailureResult;
    }
    final (exported, failure) = await _fileService.exportFile(
      exportId: finishing.id,
      source: finishing.convertedFilePath,
      destination: finishing.outputDirectoryPath,
      name: finishing.outputFileName,
    );
    if (failure != null || exported == null) {
      _exportFailures[finishing.id] = failure ?? const OutputExportFailure();
      await _jobStorage.update(
        finishing.copyWith(status: const Some(.actionRequired)),
      );
      LogData().appendLog(
        finishing.id,
        (failure ?? const OutputExportFailure()).toString(),
      );
      _finishExecution(finishing);
      _requestPendingJobs();
      return;
    }
    await _commitExport(finishing, exported);
  }

  Future<void> _commitExport(ConvertJob job, ExportedFile exported) async {
    final failure = await _jobStorage.update(
      job.copyWith(
        status: const Some(.completed),
        outputUri: Some(exported.location),
        outputFileName: Some(exported.name),
      ),
    );
    if (failure != null) throw failure;
    _exportFailures.remove(job.id);
    SettingsBox().successConversionCount++;
    try {
      await _fileService.acknowledgeExport(job.id);
      await _fileService.deleteFileAtPath(job.convertedFilePath);
      await _fileService.cleanUpInputFile(jobId: job.id);
    } finally {
      _finishExecution(job);
      _requestPendingJobs();
    }
  }

  void _finishExecution(ConvertJob job) {
    if (_activeExecutions[job.id] == job.executionId) {
      _activeExecutions.remove(job.id);
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

    final outputLocation = job.outputLocation;
    try {
      printLog(
        '[JobManagerViewModel]: Removing output file: $outputLocation',
      );
      await _fileService.deleteOutput(outputLocation);
    } catch (err, trace) {
      printError(err, trace);
      LogData().appendLog(job.id, err.toString());
      return FileDeleteFailure(outputLocation);
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

  Future<Failure?> retryExport(ConvertJob job) async {
    final current = await _jobStorage.get(job.id);
    if (current == null || current.status != .actionRequired) {
      return const InvalidStatusFailure();
    }
    await _queueJobUpdate(
      current.copyWith(status: const Some(.cleaning)),
      recoverOutput: true,
    );
    return (await _jobStorage.get(job.id))?.status == .completed
        ? null
        : _exportFailures[job.id] ?? const OutputExportFailure();
  }

  Future<Failure?> handleJobRenameAction(
    ConvertJob job,
    String newName,
  ) async {
    final current = await _jobStorage.get(job.id);
    if (current == null || current.status != .actionRequired) {
      return const InvalidStatusFailure();
    }
    final newJob = current.copyWith(
      outputFileName: Some(newName),
      status: const Some(.cleaning),
    );
    await _queueJobUpdate(newJob, recoverOutput: true);
    return (await _jobStorage.get(job.id))?.status == .completed
        ? null
        : _exportFailures[job.id] ?? const OutputExportFailure();
  }

  Future<Failure?> handleJobChooseAnotherPathAction(
    ConvertJob job,
    String newPath,
  ) async {
    final current = await _jobStorage.get(job.id);
    if (current == null || current.status != .actionRequired) {
      return const InvalidStatusFailure();
    }
    final newJob = current.copyWith(
      outputDirectoryPath: Some(newPath),
      status: const Some(.cleaning),
    );
    await _queueJobUpdate(newJob, recoverOutput: true);
    return (await _jobStorage.get(job.id))?.status == .completed
        ? null
        : _exportFailures[job.id] ?? const OutputExportFailure();
  }

  Future<bool> isOutputFileExists(ConvertJob job) async {
    try {
      if (job.outputUri != null) {
        return await _fileService.isFileExist(job.outputUri!);
      }
      return await _fileService.outputExists(
        job.outputDirectoryPath,
        job.outputFileName,
      );
    } catch (err, trace) {
      printError(err, trace);
      LogData().appendLog(job.id, err.toString());
      return false;
    }
  }

  Future<void> restartPendingJobs() async {
    await _jobStorage.fixInvalidJobs();
    final recoveryJobs = await _jobStorage.watchActionRequiredJobs().first;
    for (final job in recoveryJobs.where((job) => job.outputStaged)) {
      try {
        final exported = await _fileService.recoverExport(job.id);
        if (exported != null) await _commitExport(job, exported);
      } catch (error, trace) {
        printError(error, trace);
        LogData().appendLog(job.id, error.toString());
      }
    }
    await _runPendingJobs();
  }
}
