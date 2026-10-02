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
  Future<void>? _initialization;
  bool _isInitializing = false;
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

  /// Recover persisted work once for this app lifetime, including when Home
  /// is recreated. A failed attempt remains retryable.
  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    _isInitializing = true;
    try {
      await restartPendingJobs();
    } catch (_) {
      _initialization = null;
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> addJobs(List<ConvertJob> jobs) async {
    await _saveJobs(jobs);
    await _runPendingJobs();
  }

  /// Return once the batch is saved, independently of native startup. Setup
  /// must not roll back accepted inputs if startup later encounters an error.
  Future<void> enqueueJobs(List<ConvertJob> jobs) async {
    try {
      await _saveJobs(jobs);
    } catch (error, trace) {
      printError(error, trace);
      Error.throwWithStackTrace(const FailedToQueueJobsFailure(), trace);
    }
    _requestPendingJobs();
  }

  Future<void> _saveJobs(List<ConvertJob> jobs) async {
    final failure = await _jobStorage.addAll(jobs);
    if (failure != null) {
      throw failure;
    }
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
      final preparingJob = await _serializeJobOperation<ConvertJob?>(
        job.id,
        () async {
          final currentJob = await _jobStorage.get(job.id);
          if (_isDisposed ||
              currentJob == null ||
              !currentJob.status.isQueued) {
            return null;
          }
          final id = kUuid.v4();
          final registration = Completer<void>();
          executionId = id;
          registered = registration;
          _runnerStarts[id] = registration;
          _activeExecutions[job.id] = id;
          final preparingJob = currentJob.copyWith(
            status: const Some(.preparing),
            executionId: Some(id),
          );
          final failure = await _jobStorage.update(preparingJob);
          if (failure != null) throw failure;
          return preparingJob;
        },
      );
      if (preparingJob == null || _isDisposed) return;
      final registration = registered!;
      try {
        late final Future<ConvertJob> running;
        try {
          running = _jobRunnerService.run(preparingJob);
        } finally {
          registration.complete();
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
      if (registered case final registration? when !registration.isCompleted) {
        registration.complete();
      }
      _runnerStarts.remove(executionId);
      _startingJobs.remove(job.id);
      if (didRegister) _requestPendingJobs();
    }
  }

  Future<void> restartJob(ConvertJob job) async {
    final restarted = await _serializeJobOperation(job.id, () async {
      final currentJob = await _jobStorage.get(job.id);
      if (_isDisposed || currentJob == null || !currentJob.status.isDone) {
        return false;
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
      final failure = await _jobStorage.update(newJob);
      if (failure != null) throw failure;
      return true;
    });
    if (restarted) await _runPendingJobs();
  }

  /// Keep each job's read/change steps together without blocking other jobs or
  /// holding a lock while native conversion is running.
  Future<T> _serializeJobOperation<T>(
    String jobId,
    Future<T> Function() action,
  ) {
    final previous = _jobOperations[jobId] ?? Future<void>.value();
    final result = previous.then((_) => action());
    // Callers receive failures. The queue tail still settles so a later retry
    // or removal can run after an unsuccessful storage operation.
    final settled = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _jobOperations[jobId] = settled;
    unawaited(
      settled.then((_) {
        if (identical(_jobOperations[jobId], settled)) {
          _jobOperations.remove(jobId);
        }
      }),
    );
    return result;
  }

  Future<void> _queueJobUpdate(
    ConvertJob job, {
    bool recoverOutput = false,
    bool restoreAfterStop = false,
  }) {
    return _serializeJobOperation(job.id, () async {
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
    unawaited(SettingsBox().incrementUsageCounter(.successConversionCount));
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
    _shouldRescanQueue = true;
    final running = _isInitializing
        ? _runAfterInitialization()
        : _runPendingJobs();
    unawaited(
      running.catchError((Object err, StackTrace trace) {
        printError(err, trace);
      }),
    );
  }

  Future<void> _runAfterInitialization() async {
    await _initialization;
    if (!_isDisposed) await _runPendingJobs();
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
      final pendingJobs = await _jobStorage.getNextPendingJobs(availableSlots);
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

  Future<Failure?> removeJob(ConvertJob job) =>
      _serializeJobOperation(job.id, () async {
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

        final failure = await _jobStorage.delete(jobId);
        if (failure != null) return failure;
        _requestPendingJobs();
        await _clearRemovedJobData([jobId]);

        await _fileService.cleanUpInputFile(jobId: jobId);
        await _fileService.deleteFileAtPath(convertedFilePath);
        return null;
      });

  Future<Failure?> clearFinishedJobs(ClearFinishedJobsOption result) async {
    final removedIds = switch (result) {
      ClearFinishedJobsOption.everything =>
        await _jobStorage.removeAllFinishedJobs(),
      _ => await _jobStorage.removeOlderFinishedJobs(result.dayCount),
    };

    if (removedIds == null) {
      return const FailedToClearJobsFailure();
    }

    await _clearRemovedJobData(removedIds);
    return null;
  }

  Future<void> _clearRemovedJobData(List<String> removedIds) async {
    for (final id in removedIds) {
      _retiredSessions.remove(id);
      _exportFailures.remove(id);
    }
    if (removedIds.isNotEmpty) {
      try {
        await LogData().clearLogs(removedIds);
      } catch (err, trace) {
        // History was already removed. A log cleanup failure must not report
        // that the database transaction failed or delete output files.
        printError(err, trace);
      }
    }
  }

  Future<Failure?> retryExport(ConvertJob job) => _recoverJobAction(job);

  Future<Failure?> handleJobRenameAction(ConvertJob job, String newName) =>
      _recoverJobAction(job, outputFileName: newName);

  Future<Failure?> handleJobChooseAnotherPathAction(
    ConvertJob job,
    String newPath,
  ) => _recoverJobAction(job, outputDirectoryPath: newPath);

  Future<Failure?> _recoverJobAction(
    ConvertJob job, {
    String? outputFileName,
    String? outputDirectoryPath,
  }) async {
    // Startup may be repairing persisted statuses or committing a published
    // receipt. Let it finish before beginning a new user recovery action.
    if (_isInitializing) await _initialization;
    return _serializeJobOperation(job.id, () async {
      if (_isDisposed) return const InvalidStatusFailure();
      final current = await _jobStorage.get(job.id);
      if (_isDisposed || current == null || current.status != .actionRequired) {
        return const InvalidStatusFailure();
      }
      final changed = current.copyWith(
        outputFileName: outputFileName == null ? null : .new(outputFileName),
        outputDirectoryPath: outputDirectoryPath == null
            ? null
            : .new(outputDirectoryPath),
        status: const .new(.cleaning),
      );
      try {
        // Already inside this job's operation queue. Queueing another update
        // here would wait on itself; apply the fresh snapshot directly.
        await _handleJobUpdate(changed, recoverOutput: true);
      } catch (error, trace) {
        printError(error, trace);
        LogData().appendLog(job.id, error.toString());
        rethrow;
      }
      return (await _jobStorage.get(job.id))?.status == .completed
          ? null
          : _exportFailures[job.id] ?? const OutputExportFailure();
    });
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
    if (_isDisposed) return;
    await _jobStorage.fixInvalidJobs();
    if (_isDisposed) return;
    final recoveryJobs = await _jobStorage.watchActionRequiredJobs().first;
    for (final job in recoveryJobs.where((job) => job.outputStaged)) {
      if (_isDisposed) return;
      try {
        await _serializeJobOperation(job.id, () async {
          final current = await _jobStorage.get(job.id);
          if (_isDisposed ||
              current == null ||
              current.status != .actionRequired ||
              !current.outputStaged) {
            return;
          }
          final exported = await _fileService.recoverExport(current.id);
          if (_isDisposed) return;
          if (exported != null) await _commitExport(current, exported);
        });
      } catch (error, trace) {
        printError(error, trace);
        LogData().appendLog(job.id, error.toString());
      }
    }
    await _runPendingJobs();
  }
}
