import 'dart:async';

import 'package:converter/converter.dart';
import 'package:core/utils/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:platform_utils/platform_utils.dart';
import 'package:utils/utils.dart';

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

  List<ConvertJob> _jobs = [];

  List<ConvertJob> get pendingJobs =>
      _jobs.where((job) => job.status.isQueued).toList();

  List<ConvertJob> get runningJobs =>
      _jobs.where((job) => job.status.isProcessing).toList();

  List<ConvertJob> get completedJobs =>
      _jobs.where((job) => job.status.isDone).toList();

  void addJobs(final List<ConvertJob> jobs) {
    _jobs = [
      ..._jobs,
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

    await _jobRunnerService.stop(job);
  }

  Future<void> runJob(ConvertJob job) async {
    await _jobRunnerService.run(job);
  }

  Future<void> restartJob(ConvertJob job) async {
    final newJob = job.copyWith(
      status: const Some(JobStatus.pending),
    );
    _jobs = _jobs.toList()
      ..remove(job)
      ..add(newJob);
    notifyListeners();
    await _jobRunnerService.run(newJob);
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
    final currentJob = _jobs.firstWhereOrNull(
      (element) => element.id == job.id,
    );
    if (currentJob != null && currentJob.status.isDone) {
      job = job.copyWith(
        status: Some(currentJob.status),
      );
    }

    _jobs = _jobs.toList()
      ..remove(currentJob)
      ..add(job);
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
    for (final job in pendingJobs) {
      runJob(job);
    }
  }
}
