import 'dart:async';

import 'package:converter/converter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:platform_utils/platform_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  setUpAll(() async {
    injector.registerSingleton<FileService>(DirectFileService());
    final cache = await injector<FileService>().getAppCacheDirectory();
    directory = await cache.createTemp('native_analysis_qa_');
  });

  tearDownAll(() async {
    await directory.delete(recursive: true);
    await injector.reset();
  });

  testWidgets('asynchronous analysis supplies completed media information', (
    _,
  ) async {
    final source = '${directory.path}/source Việt "analysis".wav';
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
