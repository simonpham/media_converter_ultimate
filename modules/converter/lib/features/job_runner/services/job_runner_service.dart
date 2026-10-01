import 'dart:async';

import 'package:converter/converter.dart';
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
  final _stoppingSessions = <int, Future<bool>>{};
  final _preparations = <String, _Preparation>{};

  @override
  Stream<ConvertJob> get onJobUpdate => _jobController.stream;

  @override
  Stream<JobLog> get onLogUpdate => _logController.stream;

  @override
  Future<ConvertJob> run(ConvertJob job) {
    if (_preparations.containsKey(job.id)) {
      return Future.error(StateError('Job preparation is already running'));
    }
    final execution = job.copyWith(
      executionId: Some(job.executionId ?? kUuid.v4()),
    );
    final preparation = _Preparation(execution.executionId!);
    _preparations[job.id] = preparation;
    preparation.started = _prepareAndStart(execution, preparation).whenComplete(
      () {
        if (identical(_preparations[job.id], preparation)) {
          _preparations.remove(job.id);
        }
      },
    );
    return preparation.started;
  }

  ConvertJob _cancelPreparation(ConvertJob job) {
    final cancelled = job.copyWith(status: const Some(.cancelled));
    _jobController.add(cancelled);
    return cancelled;
  }

  Future<ConvertJob> _prepareAndStart(
    ConvertJob job,
    _Preparation preparation,
  ) async {
    _jobController.add(
      job.copyWith(
        status: const Some(JobStatus.preparing),
      ),
    );

    late final MediaInformationSession mediaInfoSession;
    try {
      mediaInfoSession = await FFprobeKit.getMediaInformation(
        job.inputFilePath,
      );
    } catch (_) {
      if (preparation.cancelRequested) return _cancelPreparation(job);
      rethrow;
    }
    if (preparation.cancelRequested) return _cancelPreparation(job);
    final mediaInfo = mediaInfoSession.getMediaInformation();
    final sourceDuration =
        ((double.tryParse('${mediaInfo?.getDuration()}') ?? 0) * 1000).toInt();
    final arguments = AudioArtworkMapping.resolve(
      CommandBuilder.parseCommand(job.command),
      attachedPictureIndexes: [
        for (final stream in mediaInfo?.getStreams() ?? [])
          if (stream.getAllProperties()?['disposition']?['attached_pic'] == 1)
            if (stream.getAllProperties()?['index'] case final int index) index,
      ],
    );
    final trim = ConversionTrim.fromArguments(arguments);
    final duration = trim?.effectiveDuration(sourceDuration) ?? sourceDuration;
    if (trim != null && sourceDuration > 0 && duration == 0) {
      throw EmptyTrimRangeFailure(job.inputFilePath);
    }

    try {
      await injector<FileService>().prepareConvertTempFolder(jobId: job.id);
    } catch (_) {
      if (preparation.cancelRequested) return _cancelPreparation(job);
      rethrow;
    }
    if (preparation.cancelRequested) return _cancelPreparation(job);

    _jobController.add(
      job.copyWith(
        status: const Some(JobStatus.ready),
      ),
    );

    final session = await FFmpegKit.executeWithArgumentsAsync(
      arguments,
      (session) async {
        final state = await session.getState();
        final exitCode = await session.getReturnCode();
        printLog(
          '[JobRunnerService] Session updated: session ${session.getSessionId()}, exitCode $exitCode, state ${state.toString()}.',
        );
        final status = state.toJobStatus(returnCode: exitCode);
        _jobController.add(
          job.copyWith(
            sessionId: Some(
              session.getSessionId(),
            ),
            duration: Some(duration),
            status: Some(status),
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
    final returnCode = await session.getReturnCode();

    printLog(
      '[JobRunnerService] Init session ${session.getSessionId()} with command:\n${job.command}',
    );
    return job.copyWith(
      sessionId: Some(sessionId),
      status: Some(state.toJobStatus(returnCode: returnCode)),
      duration: Some(duration),
    );
  }

  @override
  Future<bool> stop(ConvertJob job) {
    final sessionId = job.sessionId;
    if (sessionId == null) {
      final preparation = _preparations[job.id];
      if (preparation == null || job.executionId != preparation.executionId) {
        return Future.value(false);
      }
      return preparation.stopping ??= _stopPreparation(job, preparation);
    }
    return _stoppingSessions.putIfAbsent(
      sessionId,
      () => _stopSession(job).whenComplete(() {
        _stoppingSessions.remove(sessionId);
      }),
    );
  }

  Future<bool> _stopPreparation(
    ConvertJob job,
    _Preparation preparation,
  ) async {
    preparation.cancelRequested = true;
    _jobController.add(job.copyWith(status: const Some(.stopping)));
    final started = await preparation.started;
    if (started.status == .cancelled) return true;
    if (started.sessionId == null) return false;
    // A stop can arrive while the platform creates the encoder session.
    // In that case, wait for that session's real cancellation acknowledgement.
    return stop(started);
  }

  Future<bool> _stopSession(ConvertJob job) async {
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
          '[JobRunnerService]: Session ${job.sessionId} not found.',
        );
        return false;
      }

      final status = await NativeSessionCancellation.cancel(
        readState: session.getState,
        readReturnCode: session.getReturnCode,
        requestCancel: session.cancel,
      );

      _jobController.add(
        job.copyWith(
          status: Some(status),
        ),
      );
      return status == .cancelled;
    } catch (err, trace) {
      printError(err, trace);
      return false;
    }
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
    final returnCode = await session.getReturnCode();
    return state.toJobStatus(returnCode: returnCode);
  }
}

class _Preparation(final String executionId) {
  bool cancelRequested = false;
  late final Future<ConvertJob> started;
  Future<bool>? stopping;
}
