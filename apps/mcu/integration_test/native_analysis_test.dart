import 'dart:async';
import 'dart:convert';

import 'package:converter/converter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:platform_utils/platform_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late String source;

  setUpAll(() async {
    injector.registerSingleton<FileService>(DirectFileService());
    final cache = await injector<FileService>().getAppCacheDirectory();
    directory = await cache.createTemp('native_analysis_qa_');
    source = '${directory.path}/source Việt "analysis".wav';
    final fixture = await FFmpegKit.executeWithArguments([
      '-f',
      'lavfi',
      '-i',
      'sine=duration=2:sample_rate=48000',
      '-c:a',
      'pcm_s16le',
      source,
    ]);
    expect(ReturnCode.isSuccess(await fixture.getReturnCode()), isTrue);
  });

  tearDownAll(() async {
    await directory.delete(recursive: true);
    await injector.reset();
  });

  testWidgets('asynchronous analysis supplies completed media information', (
    _,
  ) async {
    final completed = Completer<void>();
    String? duration;
    int? sampleRate;
    final session = await FFprobeKit.getMediaInformationAsync(
      source,
      (result) {
        final information = result.getMediaInformation();
        duration = information?.getDuration();
        sampleRate = int.tryParse(
          '${information?.getStreams().single.getSampleRate()}',
        );
        completed.complete();
      },
    );
    await completed.future.timeout(const Duration(seconds: 15));
    expect(ReturnCode.isSuccess(await session.getReturnCode()), isTrue);
    expect(double.tryParse('$duration'), 2);
    expect(sampleRate, 48000);
  });

  testWidgets('Stop during analysis prevents encoder startup', (_) async {
    final service = injector<FileService>();
    final job = await _job(service, source);
    final runner = FfmpegJobRunnerService();
    final events = <ConvertJob>[];
    final preparing = Completer<void>();
    final subscription = runner.onJobUpdate.listen((event) {
      events.add(event);
      if (event.status == .preparing && !preparing.isCompleted) {
        preparing.complete();
      }
    });
    final sessionsBefore = (await FFmpegKit.listSessions()).length;
    try {
      final running = runner.run(job);
      await preparing.future.timeout(const Duration(seconds: 10));
      final stopped = await runner.stop(job);
      expect(stopped, isTrue);
      expect((await running).status, JobStatus.cancelled);
      await Future<void>.delayed(Duration.zero);
      expect(events.map((job) => job.status), contains(JobStatus.stopping));
      expect(
        events.any((job) => job.status == .ready || job.status == .running),
        isFalse,
      );
      expect(events.every((job) => job.sessionId == null), isTrue);
      expect((await FFmpegKit.listSessions()).length, sessionsBefore);
      expect(await File(job.convertedFilePath).exists(), isFalse);
      expect(await File(source).exists(), isTrue);
    } finally {
      await subscription.cancel();
      final temporary = await service.getConvertTemporaryDirectory(job.id);
      if (await temporary.exists()) await temporary.delete(recursive: true);
    }
  });

  testWidgets('Stop waits for folder setup and never launches the encoder', (
    _,
  ) async {
    final service = _GatedFiles();
    injector.unregister<FileService>();
    injector.registerSingleton<FileService>(service);
    final job = await _job(service, source);
    final runner = FfmpegJobRunnerService();
    final events = <ConvertJob>[];
    final subscription = runner.onJobUpdate.listen(events.add);
    final sessionsBefore = (await FFmpegKit.listSessions()).length;
    final running = runner.run(job);
    Future<bool>? stopped;
    var acknowledged = false;
    try {
      await service.entered.future.timeout(const Duration(seconds: 10));
      stopped = runner.stop(job).then((result) {
        acknowledged = result;
        return result;
      });
      final duplicate = runner.stop(job);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(acknowledged, isFalse);
      expect(events.last.status, JobStatus.stopping);
      expect((await FFmpegKit.listSessions()).length, sessionsBefore);
      expect(await File(job.convertedFilePath).exists(), isFalse);
      service.release.complete();
      expect(await stopped, isTrue);
      expect(await duplicate, isTrue);
      expect((await running).status, JobStatus.cancelled);
      await Future<void>.delayed(Duration.zero);
      expect(events.where((job) => job.status == .cancelled), hasLength(1));
      expect(
        events.any((job) => job.status == .ready || job.status == .running),
        isFalse,
      );
      expect((await FFmpegKit.listSessions()).length, sessionsBefore);
      expect(await File(job.convertedFilePath).exists(), isFalse);
      expect(await File(source).exists(), isTrue);
    } finally {
      if (!service.release.isCompleted) service.release.complete();
      await running;
      await stopped;
      await subscription.cancel();
      final temporary = await service.getConvertTemporaryDirectory(job.id);
      if (await temporary.exists()) await temporary.delete(recursive: true);
      injector.unregister<FileService>();
      injector.registerSingleton<FileService>(DirectFileService());
    }
  });

  testWidgets('Stop at encoder startup waits for native cancellation', (
    _,
  ) async {
    final service = injector<FileService>();
    final job = await _job(service, source, realTime: true);
    final runner = FfmpegJobRunnerService();
    final stopped = Completer<bool>();
    final events = <ConvertJob>[];
    final subscription = runner.onJobUpdate.listen((event) {
      events.add(event);
      if (event.status == .ready) {
        unawaited(
          runner
              .stop(job)
              .then(stopped.complete, onError: stopped.completeError),
        );
      }
    });
    try {
      final started = await runner.run(job);
      expect(started.sessionId, isNotNull);
      expect(await stopped.future.timeout(const Duration(seconds: 15)), isTrue);
      final sessions = await FFmpegKit.listSessions();
      final native = sessions.singleWhere(
        (session) => session.getSessionId() == started.sessionId,
      );
      expect(ReturnCode.isCancel(await native.getReturnCode()), isTrue);
      expect(await native.getState(), isNot(SessionState.running));
      await Future<void>.delayed(Duration.zero);
      expect(events.last.status, JobStatus.cancelled);
      expect(events.last.sessionId, started.sessionId);
      expect(await File(source).exists(), isTrue);
    } finally {
      if (!stopped.isCompleted) {
        await stopped.future.timeout(const Duration(seconds: 15));
      }
      await subscription.cancel();
      final temporary = await service.getConvertTemporaryDirectory(job.id);
      if (await temporary.exists()) await temporary.delete(recursive: true);
    }
  });

  testWidgets('analysis cancellation cannot invent a cancelled return code', (
    _,
  ) async {
    final completed = Completer<void>();
    final session =
        await FFprobeKit.getMediaInformationFromCommandArgumentsAsync(
          [
            '-v',
            'error',
            '-f',
            'lavfi',
            '-i',
            'testsrc=size=1920x1080:rate=30:duration=60',
            '-count_frames',
            '-show_streams',
            '-show_format',
            '-of',
            'json',
          ],
          (_) => completed.complete(),
        );
    try {
      for (var attempt = 0; attempt < 40; attempt++) {
        if (await session.getState() != .created) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(await session.getState(), SessionState.running);
      JobStatus? acknowledged;
      try {
        acknowledged = await NativeSessionCancellation.cancel(
          readState: session.getState,
          readReturnCode: session.getReturnCode,
          requestCancel: session.cancel,
          timeout: const Duration(seconds: 3),
        );
      } on TimeoutException {
        // Some bundled engines do not interrupt FFprobe. Retain the slot until
        // the finite probe ends, rather than fabricating cancellation.
      }
      await completed.future.timeout(const Duration(seconds: 45));
      final code = await session.getReturnCode();
      final state = await session.getState();
      expect(state == .completed || state == .failed, isTrue);
      if (acknowledged != null) {
        expect(acknowledged, state.toJobStatus(returnCode: code));
      }
      if (!ReturnCode.isCancel(code)) {
        expect(acknowledged, isNot(JobStatus.cancelled));
      }
    } finally {
      await completed.future.timeout(const Duration(seconds: 45));
      printLog(
        '[Analysis QA] Final state: ${await session.getState()}, '
        'return code: ${await session.getReturnCode()}',
      );
    }
  });
}

Future<ConvertJob> _job(
  FileService service,
  String source, {
  bool realTime = false,
}) async {
  final id = 'native-stop-${DateTime.now().microsecondsSinceEpoch}';
  final temporary = await service.getConvertTemporaryDirectory(id);
  final output = '${temporary.path}/output.m4a';
  final now = DateTime.now();
  return ConvertJob(
    id: id,
    executionId: '$id-execution',
    inputFilePath: source,
    outputFileName: 'output.m4a',
    outputExtension: 'm4a',
    outputDirectoryPath: temporary.path,
    command: jsonEncode([
      if (realTime) '-re',
      '-i',
      source,
      '-c:a',
      'aac',
      output,
    ]),
    convertedFilePath: output,
    createdAt: now,
    updatedAt: now,
  );
}

class _GatedFiles extends DirectFileService {
  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> prepareConvertTempFolder({required String jobId}) async {
    entered.complete();
    await release.future;
    await super.prepareConvertTempFolder(jobId: jobId);
  }
}
