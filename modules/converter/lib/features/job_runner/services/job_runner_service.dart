import 'dart:async';

import 'package:converter/converter.dart';
import 'package:core/core.dart';
import 'package:platform_utils/platform_utils.dart';
import 'package:utils/utils.dart';

abstract interface class JobRunnerService {
  Future<ConvertJob> run(ConvertJob job);

  Future<bool> stop(ConvertJob job);

  Future<JobStatus> getStatus(String sessionId);

  Stream<ConvertJob> get onJobUpdate;

  Stream<JobLog> get onLogUpdate;
}

class FfmpegJobRunnerService implements JobRunnerService {
  final StreamController<ConvertJob> _jobController =
      StreamController.broadcast();
  final StreamController<JobLog> _logController = StreamController.broadcast();

  @override
  Stream<ConvertJob> get onJobUpdate => _jobController.stream;

  @override
  Stream<JobLog> get onLogUpdate => _logController.stream;

  @override
  Future<ConvertJob> run(ConvertJob job) async {
    _jobController.add(
      job.copyWith(
        status: const Some(JobStatus.preparing),
      ),
    );

    final mediaInfoSession = await FFprobeKit.getMediaInformation(
      job.inputFilePath,
    );
    final mediaInfo = mediaInfoSession.getMediaInformation();
    final duration =
        ((double.tryParse('${mediaInfo?.getDuration()}') ?? 0) * 1000).toInt();

    await injector<FileService>().prepareConvertTempFolder(jobId: job.id);

    _jobController.add(
      job.copyWith(
        status: const Some(JobStatus.ready),
      ),
    );

    final session = await FFmpegKit.executeAsync(
      job.command,
      (session) async {
        final state = await session.getState();
        final exitCode = await session.getReturnCode();
        printLog(
          '[JobRunnerService] Session updated: session ${session.getSessionId()}, exitCode $exitCode, state ${state.toString()}.',
        );
        final status = exitCode == null
            ? state.toJobStatus()
            : exitCode.isValueSuccess()
            ? JobStatus.cleaning
            : exitCode.isValueCancel()
            ? JobStatus.cancelled
            : exitCode.isValueError()
            ? JobStatus.failed
            : null;
        _jobController.add(
          job.copyWith(
            sessionId: Some(
              session.getSessionId(),
            ),
            duration: Some(duration),
            status: status != null ? Some(status) : null,
          ),
        );
      },
      (log) {
        final msg =
            '[${log.getSessionId()}] - ${log.getLevel()}: ${log.getMessage()}';
        _logController.add(
          JobLog(
            jobId: job.id,
            message: msg,
          ),
        );
      },
      (stats) async {
        final progress = stats.getTime();
        final sessionId = stats.getSessionId();
        printLog(
          '[JobRunnerService] Stats updated: progress $progress, duration $duration.',
        );
        _jobController.add(
          job.copyWith(
            sessionId: Some(sessionId),
            progress: Some(progress),
            duration: Some(duration),
            status: const Some(JobStatus.running),
          ),
        );
      },
    );

    final sessionId = session.getSessionId();
    if (sessionId == null) {
      throw Exception('Failed to get session id');
    }

    final state = await session.getState();

    printLog(
      '[JobRunnerService] Init session ${session.getSessionId()} with command:\n${job.command}',
    );
    return job.copyWith(
      sessionId: Some(sessionId),
      status: Some(state.toJobStatus()),
      duration: Some(duration),
    );
  }

  @override
  Future<bool> stop(ConvertJob job) async {
    if (job.sessionId == null) {
      return false;
    }

    try {
      final sessions = await FFmpegKit.listSessions();
      if (sessions.isEmpty) {
        printLog('[JobRunnerService]: No sessions found');
        return false;
      }

      printLog(
        '[JobRunnerService]: Current sessions: ${sessions.map((e) => e.getSessionId()).join(', ')}',
      );
      final session = sessions.firstWhereOrNull(
        (element) => element.getSessionId() == job.sessionId,
      );
      if (session == null) {
        printLog(
          '[JobRunnerService]: Session ${job.sessionId} not found. Cancel anyway.',
        );
        _jobController.add(
          job.copyWith(
            status: const Some(JobStatus.cancelled),
          ),
        );
        return false;
      }

      await session.cancel();

      _jobController.add(
        job.copyWith(
          status: const Some(JobStatus.cancelled),
        ),
      );
    } catch (err, trace) {
      printError(err, trace);
      return false;
    }

    return true;
  }

  @override
  Future<JobStatus> getStatus(String sessionId) async {
    final sessions = await FFmpegKit.listSessions();
    if (sessions.isEmpty) {
      throw Exception('Failed to get sessions');
    }

    final session = sessions.firstWhere(
      (element) => element.getSessionId()?.toString() == sessionId,
    );

    final state = await session.getState();
    return state.toJobStatus();
  }
}
