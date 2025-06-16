import 'dart:async';

import 'package:converter/converter.dart';
import 'package:core/core.dart';
import 'package:platform_utils/platform_utils.dart';
import 'package:utils/utils.dart';

abstract interface class JobRunnerService {
  Future<ConvertJob> run(ConvertJob job);

  Future<bool> stop(String sessionId);

  Future<JobStatus> getStatus(String sessionId);

  Stream<ConvertJob> get onJobUpdate;

  Stream<String> get onLogUpdate;
}

class FfmpegJobRunnerService implements JobRunnerService {
  final StreamController<ConvertJob> _jobController =
      StreamController.broadcast();
  final StreamController<String> _logController = StreamController.broadcast();

  @override
  Stream<ConvertJob> get onJobUpdate => _jobController.stream;

  @override
  Stream<String> get onLogUpdate => _logController.stream;

  @override
  Future<ConvertJob> run(ConvertJob job) async {
    final mediaInfo = await FFprobeKit.getMediaInformation(job.inputFilePath);
    final duration = int.tryParse(
      '${await mediaInfo.getDuration()}',
    );

    final session = await FFmpegKit.executeAsync(
      job.command,
      (session) async {
        final state = await session.getState();
        _jobController.add(
          job.copyWith(
            sessionId: Some(
              session.getSessionId(),
            ),
            duration: Some(duration),
            status: Some(state.toJobStatus()),
          ),
        );
      },
      (log) {
        _logController.add(
          '[${log.getSessionId()}] - ${log.getLevel()}: ${log.getMessage()}',
        );
      },
      (stats) async {
        final progress = stats.getTime();
        _jobController.add(
          job.copyWith(
            sessionId: Some(
              stats.getSessionId(),
            ),
            progress: Some(progress),
            duration: Some(duration),
          ),
        );
      },
    );

    final sessionId = session.getSessionId();
    if (sessionId == null) {
      throw Exception('Failed to get session id');
    }

    final state = await session.getState();

    return job.copyWith(
      sessionId: Some(sessionId),
      status: Some(state.toJobStatus()),
      duration: Some(duration),
    );
  }

  @override
  Future<bool> stop(String sessionId) async {
    try {
      final sessions = await FFmpegKit.listSessions();
      if (sessions.isEmpty) {
        return false;
      }

      final session = sessions.firstWhereOrNull(
        (element) => element.getSessionId()?.toString() == sessionId,
      );
      if (session == null) {
        return false;
      }

      await session.cancel();
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
