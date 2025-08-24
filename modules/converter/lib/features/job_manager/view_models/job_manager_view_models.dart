import 'dart:async';

import 'package:converter/converter.dart';
import 'package:core/utils/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:platform_utils/platform_utils.dart';

class JobManagerViewModel extends ChangeNotifier {
  final JobRunnerService _jobRunnerService;

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

  @override
  void dispose() {
    _jobSubscription?.cancel();
    _logSubscription?.cancel();
    super.dispose();
  }

  List<ConvertJob> _pendingJobs = [];
  List<ConvertJob> _runningJobs = [];
  List<ConvertJob> _completedJobs = [];

  List<ConvertJob> get pendingJobs => _pendingJobs;

  List<ConvertJob> get runningJobs => _runningJobs;

  List<ConvertJob> get completedJobs => _completedJobs;

  void addJobs(final List<ConvertJob> jobs) {
    _pendingJobs = [
      ..._pendingJobs,
      ...jobs,
    ];
    notifyListeners();
    _runPendingJobs();
  }

  Future<void> removeRunningJob(ConvertJob job) async {
    final sessionId = job.sessionId;
    if (sessionId == null) {
      return;
    }

    await _jobRunnerService.stop('$sessionId');
  }

  Future<void> runJob(ConvertJob job) async {
    await _jobRunnerService.run(job);
  }

  void _handleJobUpdate(ConvertJob job) {
    _updateJobInList(job);

    if (job.status == JobStatus.completed) {
      _completeJob(job);
    }
  }

  void _handleLogUpdate(JobLog event) {
    final jobId = event.jobId;
    final message = event.message;
    printLog('[JobManagerViewModel]: Log: $message');
    LogData().appendLog(jobId, message);
  }

  void _updateJobInList(ConvertJob job) {
    /// Remove old job from list.
    final isJobInPending = _pendingJobs.any(
      (element) => element.id == job.id,
    );
    if (isJobInPending) {
      _pendingJobs = _pendingJobs.toList()
        ..removeWhere(
          (element) => element.id == job.id,
        );
    }

    final isJobInRunning = _runningJobs.any(
      (element) => element.id == job.id,
    );
    if (isJobInRunning) {
      _runningJobs = _runningJobs.toList()
        ..removeWhere(
          (element) => element.id == job.id,
        );
    }

    final isJobInCompleted = _completedJobs.any(
      (element) => element.id == job.id,
    );
    if (isJobInCompleted) {
      _completedJobs = _completedJobs.toList()
        ..removeWhere(
          (element) => element.id == job.id,
        );
    }

    /// Add updated job to list.
    switch (job.status) {
      case JobStatus.preparing:
      case JobStatus.ready:
      case JobStatus.pending:
        _pendingJobs = _pendingJobs.toList()..add(job);
        break;
      case JobStatus.running:
        _runningJobs = _runningJobs.toList()..add(job);
        break;
      case JobStatus.failed:
      case JobStatus.completed:
        _completedJobs = _completedJobs.toList()..add(job);
        break;
    }
    notifyListeners();
  }

  Future<void> _completeJob(ConvertJob job) async {
    final success = await FileUtils.moveTempFileToPath(
      fileName: job.outputFileName,
      path: job.outputDirectoryPath,
    );
    if (!success) {
      return;
    }
    notifyListeners();
  }

  void _runPendingJobs() {
    for (final job in _pendingJobs) {
      runJob(job);
    }
  }
}
