import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:converter/converter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mcu/theme_adapter.dart';
import 'package:platform_utils/platform_utils.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Directory cache;
  late String source;
  final previews = <MediaPreviewSession>[];

  setUpAll(() async {
    final base = await DirectFileService().getAppCacheDirectory();
    directory = await base.createTemp('native_trim_qa_');
    cache = await Directory('${directory.path}/preview-cache').create();
    injector.registerSingleton<FileService>(_Files(cache));
    injector.registerSingleton<SettingsBox>(_Settings());
    injector.registerFactory<MediaPreviewSession>(() {
      final session = FfmpegMediaPreviewSession();
      previews.add(session);
      return session;
    });
    source = '${directory.path}/red blue Việt "preview".mkv';
    await _execute([
      '-f',
      'lavfi',
      '-i',
      'color=c=red:s=128x96:r=10:d=2',
      '-f',
      'lavfi',
      '-i',
      'color=c=blue:s=128x96:r=10:d=2',
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=440:sample_rate=48000:duration=4',
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=880:sample_rate=48000:duration=4',
      '-filter_complex',
      '[0:v][1:v]concat=n=2:v=1:a=0[v];[2:a]volume=0.02[a1];[3:a]volume=0.02[a2]',
      '-map',
      '[v]',
      '-map',
      '[a1]',
      '-map',
      '[a2]',
      '-c:v',
      'libx264',
      '-colorspace',
      'bt709',
      '-preset',
      'ultrafast',
      '-c:a',
      'pcm_s16le',
      '-disposition:a:0',
      '0',
      '-disposition:a:1',
      'default',
      source,
    ]);
  });

  tearDown(() async {
    for (final preview in previews) {
      await preview.close();
    }
    previews.clear();
    expect(await cache.list().toList(), isEmpty);
    expect(await File(source).exists(), isTrue);
  });

  tearDownAll(() async {
    await directory.delete(recursive: true);
    await injector.reset();
  });

  testWidgets(
    'probe chooses the default audio track and decodes changing frame previews',
    (_) async {
      final preview = injector<MediaPreviewSession>();
      final info = await preview.inspect(source);
      expect(info.duration.inMilliseconds, closeTo(4000, 100));
      expect(info.videoIndex, 0);
      expect(info.audioIndex, 2);
      final red = await _pixel(
        (await preview.frame(source, const Duration(milliseconds: 750)))!,
      );
      final blue = await _pixel(
        (await preview.frame(source, const Duration(milliseconds: 2500)))!,
      );
      expect(red.$1, greaterThan(red.$3));
      expect(blue.$3, greaterThan(blue.$1));
      final last = await preview.frame(source, info.duration);
      expect(last, isNotNull);
      final wave = await preview.waveform(
        source,
        Duration.zero,
        const Duration(seconds: 4),
        '800080',
      );
      final codec = await ui.instantiateImageCodec(
        await File(wave!).readAsBytes(),
      );
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 640);
      expect(frame.image.height, 96);
      frame.image.dispose();
      codec.dispose();
    },
  );

  testWidgets(
    'audio playback reports absolute positions and uses the selected default track',
    (tester) async {
      final preview = injector<MediaPreviewSession>();
      await preview.inspect(source);
      final finished = Completer<void>();
      final positions = <Duration>[];
      final sub = preview.positions.listen(positions.add);
      final completion = preview.completed.listen((_) {
        if (!finished.isCompleted) finished.complete();
      });
      try {
        expect(
          await preview.play(
            source,
            const Duration(milliseconds: 750),
            const Duration(milliseconds: 1750),
          ),
          isTrue,
        );
        await tester.pumpAndSettle(const Duration(milliseconds: 50));
        await finished.future.timeout(const Duration(seconds: 8));
        expect(preview.audioEnd, const Duration(milliseconds: 1750));
        expect(positions, isNotEmpty);
        expect(
          positions.first,
          greaterThanOrEqualTo(const Duration(milliseconds: 750)),
        );
        expect(
          positions.any((p) => p > const Duration(milliseconds: 900)),
          isTrue,
        );
        final folder = (await cache.list().toList())
            .whereType<Directory>()
            .single;
        final raw = '${directory.path}/actual.pcm';
        final reference = '${directory.path}/reference.pcm';
        await _execute(['-i', '${folder.path}/audio.wav', '-f', 's16le', raw]);
        await _execute([
          '-ss',
          '0.750',
          '-i',
          source,
          '-map',
          '0:2',
          '-t',
          '1.000',
          '-ar',
          '48000',
          '-ac',
          '2',
          '-f',
          's16le',
          reference,
        ]);
        expect(
          await File(raw).readAsBytes(),
          orderedEquals(await File(reference).readAsBytes()),
        );
      } finally {
        await sub.cancel();
        await completion.cancel();
      }
    },
  );

  testWidgets(
    'pause suppresses stale playback events and can start a new cursor',
    (tester) async {
      final preview = injector<MediaPreviewSession>();
      await preview.inspect(source);
      final positions = <Duration>[];
      final sub = preview.positions.listen(positions.add);
      try {
        expect(
          await preview.play(source, Duration.zero, const Duration(seconds: 4)),
          isTrue,
        );
        await tester.pump(const Duration(milliseconds: 250));
        await preview.pause();
        final pausedCount = positions.length;
        await tester.pump(const Duration(milliseconds: 250));
        expect(positions.length, pausedCount);
        positions.clear();
        expect(
          await preview.play(
            source,
            const Duration(milliseconds: 2500),
            const Duration(seconds: 4),
          ),
          isTrue,
        );
        await tester.pump(const Duration(milliseconds: 250));
        expect(
          positions.every((p) => p >= const Duration(milliseconds: 2500)),
          isTrue,
        );
      } finally {
        await preview.pause();
        await sub.cancel();
      }
    },
  );

  testWidgets('audio-only preview bounds its decoded clip to 30 seconds', (
    _,
  ) async {
    final audio = '${directory.path}/long silence.flac';
    await _execute([
      '-f',
      'lavfi',
      '-i',
      'anullsrc=r=48000:cl=stereo',
      '-t',
      '65',
      '-c:a',
      'flac',
      audio,
    ]);
    final preview = injector<MediaPreviewSession>();
    final info = await preview.inspect(audio);
    expect(info.videoIndex, isNull);
    expect(await preview.frame(audio, Duration.zero), isNull);
    expect(await preview.play(audio, Duration.zero, info.duration), isTrue);
    await preview.pause();
    expect(preview.audioEnd, const Duration(seconds: 30));
    final folder = (await cache.list().toList()).whereType<Directory>().single;
    final clip = File('${folder.path}/audio.wav');
    expect(await clip.length(), lessThan(6000000));
    final probe = await FFprobeKit.executeWithArguments([
      '-v',
      'error',
      '-show_format',
      '-of',
      'json',
      clip.path,
    ]);
    expect(ReturnCode.isSuccess(await probe.getReturnCode()), isTrue);
    final format = jsonDecode((await probe.getOutput())!)['format'] as Map;
    expect(double.parse(format['duration'] as String), 30);
  });

  testWidgets('pause during preparation prevents deferred player startup', (
    _,
  ) async {
    final preview = injector<MediaPreviewSession>();
    await preview.inspect(source);
    final playing = preview.play(
      source,
      Duration.zero,
      const Duration(seconds: 4),
    );
    await preview.pause();
    expect(await playing, isFalse);
  });

  testWidgets(
    'closing preview waits for its own native rendering before deleting cache',
    (_) async {
      final preview = injector<MediaPreviewSession>();
      await preview.inspect(source);
      final unrelated = Completer<FFmpegSession>();
      await FFmpegKit.executeWithArgumentsAsync(
        ['-re', '-f', 'lavfi', '-i', 'sine=duration=1', '-f', 'null', '-'],
        (session) => unrelated.complete(session),
      );
      final rendering = preview
          .waveform(source, Duration.zero, const Duration(seconds: 4), '800080')
          .then((_) => true, onError: (Object _, StackTrace _) => false);
      await preview.close();
      await rendering;
      expect(
        ReturnCode.isSuccess(await (await unrelated.future).getReturnCode()),
        isTrue,
      );
      expect(await cache.list().toList(), isEmpty);
    },
  );

  testWidgets('timeline controls apply exact times back to the trim fields', (
    tester,
  ) async {
    final formats = FormatConfigModel.fromJson(
      jsonDecode(await rootBundle.loadString('assets/configs/format.json')),
    );
    final theme = FluffyThemeData.fromJson(
      jsonDecode(await rootBundle.loadString('assets/themes/default.json')),
    );
    final model = JobMakerViewModel(
      formatConfigModel: formats,
      translations: const {},
    );
    await model.addFiles([File(source)]);
    model.setTrimRange(
      const ConversionTrim(
        start: Duration(milliseconds: 750),
        end: Duration(milliseconds: 1750),
      ),
    );
    try {
      await tester.pumpWidget(
        ChangeNotifierProvider<JobMakerViewModel>.value(
          value: model,
          child: MaterialApp(
            theme: theme.getTheme(isDark: false),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => FluffyTheme(
              data: theme.getFluffyTheme(isDark: false),
              child: child!,
            ),
            home: const Scaffold(
              body: SingleChildScrollView(child: TrimEditor()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Preview & trim'));
      await tester.pumpAndSettle();
      await _until(
        tester,
        () => find
            .byKey(const ValueKey('trim-range-slider'))
            .evaluate()
            .isNotEmpty,
      );
      await tester.ensureVisible(find.text('+0.1 s'));
      await tester.tap(find.text('+0.1 s'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set start here'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+1.0 s'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set end here'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply range'));
      await tester.pumpAndSettle();
      expect(model.trimStartText, '00:00.850');
      expect(model.trimEndText, '00:01.850');
      expect(model.selectedTrim!.arguments, ['-ss', '0.850', '-t', '1.000']);
      expect(find.text('00:00.850'), findsOneWidget);
      expect(find.text('00:01.850'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
    }
  });
}

Future<void> _execute(List<String> arguments) async {
  final session = await FFmpegKit.executeWithArguments(['-y', ...arguments]);
  expect(
    ReturnCode.isSuccess(await session.getReturnCode()),
    isTrue,
    reason: await session.getOutput(),
  );
}

Future<(int, int, int)> _pixel(String path) async {
  final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
  final frame = await codec.getNextFrame();
  final data = (await frame.image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!;
  final index =
      ((frame.image.height ~/ 2) * frame.image.width + frame.image.width ~/ 2) *
      4;
  final result = (
    data.getUint8(index),
    data.getUint8(index + 1),
    data.getUint8(index + 2),
  );
  frame.image.dispose();
  codec.dispose();
  return result;
}

Future<void> _until(WidgetTester tester, bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(condition(), isTrue);
}

class _Files(final Directory cache) extends DirectFileService {
  @override
  Future<Directory> getAppCacheDirectory() async => cache;
}

class _Settings implements SettingsBox {
  @override
  dynamic get(dynamic key, {required dynamic defaultValue}) => defaultValue;
  @override
  Future<void> put(dynamic key, dynamic value) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
