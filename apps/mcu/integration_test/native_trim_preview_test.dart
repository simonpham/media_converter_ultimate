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
      final strip = await preview.thumbnails(
        source,
        Duration.zero,
        info.duration,
      );
      expect(strip, isNotNull);
      final stripStart = await _pixel(strip!, horizontal: 0.05);
      final stripEnd = await _pixel(strip, horizontal: 0.95);
      expect(stripStart.$1, greaterThan(stripStart.$3));
      expect(stripEnd.$3, greaterThan(stripEnd.$1));
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

  testWidgets('full waveform preserves quiet audio, late peaks and cache', (
    _,
  ) async {
    final audio = '${directory.path}/ninety-second overview.wav';
    await _execute([
      '-f',
      'lavfi',
      '-i',
      "aevalsrc='if(lt(t,5),0.02*sin(2*PI*440*t),if(gte(t,85),0.8*sin(2*PI*880*t),0))':s=48000:d=90",
      '-af',
      'pan=stereo|c0=c0|c1=-1*c0',
      '-c:a',
      'pcm_s16le',
      audio,
    ]);
    final escapedCache = await Directory(
      "${cache.path}/wave-cache Việt ' :[,]",
    ).create();
    final files = injector<FileService>() as _Files;
    files.previewCache = escapedCache;
    final preview = injector<MediaPreviewSession>();
    addTearDown(() async {
      await preview.close();
      await escapedCache.delete();
    });
    late PreviewMediaInfo info;
    try {
      info = await preview.inspect(audio);
    } finally {
      files.previewCache = null;
    }
    expect(info.duration.inSeconds, 90);
    final wave = await preview.waveform(
      audio,
      Duration.zero,
      info.duration,
      '800080',
    );
    expect(wave, isNotNull);
    expect(await _waveHeight(wave!, 0.03), inInclusiveRange(8, 20));
    expect(await _waveHeight(wave, 0.5), 0);
    expect(await _waveHeight(wave, 0.97), greaterThan(75));
    // Opposite-phase stereo must remain visible rather than cancel in downmix.
    final zoom = await preview.waveform(
      audio,
      const Duration(seconds: 80),
      const Duration(seconds: 10),
      '800080',
    );
    expect(await _waveHeight(zoom!, 0.25), 0);
    expect(await _waveHeight(zoom, 0.75), greaterThan(75));
    for (var i = 0; i < 5; i++) {
      await preview.waveform(
        audio,
        Duration(seconds: i * 10),
        const Duration(seconds: 5),
        '800080',
      );
    }
    expect(
      await preview.waveform(audio, Duration.zero, info.duration, '800080'),
      wave,
    );
    expect(await File(wave).exists(), isTrue);
    final folder = File(wave).parent;
    final cachedFiles = await folder.list().toList();
    expect(cachedFiles.length, 4);
    expect(cachedFiles.every((file) => file.path.endsWith('.png')), isTrue);
  });

  testWidgets('overview thumbnails sample both ends of a long video', (
    _,
  ) async {
    final longSource = '${directory.path}/long overview.mkv';
    await _execute([
      '-f',
      'lavfi',
      '-i',
      'color=c=red:s=128x96:r=1:d=30',
      '-f',
      'lavfi',
      '-i',
      'color=c=blue:s=128x96:r=1:d=30',
      '-filter_complex',
      '[0:v][1:v]concat=n=2:v=1:a=0[v]',
      '-map',
      '[v]',
      '-c:v',
      'libx264',
      '-preset',
      'ultrafast',
      longSource,
    ]);
    final preview = injector<MediaPreviewSession>();
    final information = await preview.inspect(longSource);
    expect(information.duration.inSeconds, 60);
    final strip = await preview.thumbnails(
      longSource,
      Duration.zero,
      information.duration,
    );
    expect(strip, isNotNull);
    final first = await _pixel(strip!, horizontal: 0.05);
    final last = await _pixel(strip, horizontal: 0.95);
    expect(first.$1, greaterThan(first.$3));
    expect(last.$3, greaterThan(last.$1));
    final middle = await preview.thumbnails(
      longSource,
      const Duration(seconds: 20),
      const Duration(seconds: 40),
    );
    final middleStart = await _pixel(middle!, horizontal: 0.05);
    final middleEnd = await _pixel(middle, horizontal: 0.95);
    expect(middleStart.$1, greaterThan(middleStart.$3));
    expect(middleEnd.$3, greaterThan(middleEnd.$1));
  });

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

  testWidgets(
    'review trims one file through the timeline and converts independent ranges',
    (tester) async {
      final second = '${directory.path}/short second.wav';
      final full = '${directory.path}/full third.wav';
      await _execute([
        '-f',
        'lavfi',
        '-i',
        'anullsrc=r=48000:cl=mono',
        '-t',
        '2',
        second,
      ]);
      await _execute([
        '-f',
        'lavfi',
        '-i',
        'anullsrc=r=48000:cl=mono',
        '-t',
        '3',
        full,
      ]);
      final formats = FormatConfigModel.fromJson(
        jsonDecode(await rootBundle.loadString('assets/configs/format.json')),
      );
      final theme = FluffyThemeData.fromJson(
        jsonDecode(await rootBundle.loadString('assets/themes/default.json')),
      );
      injector.registerSingleton<JobConfigurationData>(_Configurations());
      final model = JobMakerViewModel(
        formatConfigModel: formats,
        translations: const {},
      );
      await model.addFiles([File(source), File(second), File(full)]);
      await model.setSelectedFormatEntry(
        formats.formats.firstWhere((f) => f.name == 'wav'),
      );
      final output = await Directory('${directory.path}/review-output')
          .create();
      model.setOutputDirectoryPath(output.path);
      model.setOutputFileName(source, 'timeline.wav');
      model.setFileTrim(
        source,
        const FileTrimResult(
          duration: Duration(seconds: 4),
          trim: ConversionTrim(
            start: Duration(milliseconds: 750),
            end: Duration(milliseconds: 1750),
          ),
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
              home: const Scaffold(body: JobMakerPreview()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        Future<void> open(String path) async {
          final button = find.byKey(ValueKey('trim-file-$path'));
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
          await _until(
            tester,
            () => tester
                .widget<Button>(find.byKey(const ValueKey('file-trim-apply')))
                .enable,
          );
        }

        await open(source);
        await _until(
          tester,
          () => find
              .byKey(const ValueKey('trim-visual-track'))
              .evaluate()
              .isNotEmpty,
        );
        final visual = find.byKey(const ValueKey('trim-visual-track'));
        await tester.ensureVisible(visual);
        final track = tester.getRect(visual);
        final usable = track.width - Spacing.d48;
        await tester.dragFrom(
          Offset(track.left + Spacing.d24 + usable * 0.1875, track.center.dy),
          Offset(usable * 0.2, 0),
        );
        await tester.pumpAndSettle();
        expect(model.trimFor(source)!.start, const Duration(milliseconds: 750));
        final timeline = tester.element(visual).read<TrimTimelineViewModel>();
        expect(timeline.start, greaterThan(1000));
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('trim-start')),
            matching: find.byType(EditableText),
          ),
          '0:00.850',
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('trim-fine-toggle')),
        );
        await tester.tap(find.byKey(const ValueKey('trim-fine-toggle')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('trim-fine-target-end')),
        );
        await tester.tap(find.byKey(const ValueKey('trim-fine-target-end')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('+0.1 s'));
        await tester.tap(find.text('+0.1 s'));
        await tester.pumpAndSettle();
        expect(timeline.start, 850);
        expect(timeline.end, 1850);
        expect(model.trimFor(source)!.start, const Duration(milliseconds: 750));
        await tester.tap(find.byKey(const ValueKey('file-trim-apply')));
        await tester.pumpAndSettle();
        expect(model.trimFor(source)!.arguments, [
          '-ss',
          '0.850',
          '-t',
          '1.000',
        ]);
        expect(model.trimFor(second), isNull);
        expect(model.trimFor(full), isNull);
        await open(second);
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('trim-start')),
            matching: find.byType(EditableText),
          ),
          '0:00.500',
        );
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('trim-end')),
            matching: find.byType(EditableText),
          ),
          '0:02.001',
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Button>(find.byKey(const ValueKey('file-trim-apply')))
              .enable,
          isFalse,
        );
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('trim-end')),
            matching: find.byType(EditableText),
          ),
          '0:01.500',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('file-trim-apply')));
        await tester.pumpAndSettle();
        final jobs = await model.cook();
        for (var i = 0; i < jobs.length; i++) {
          final args = CommandBuilder.parseCommand(jobs[i].command);
          if (i == 2) {
            expect(args, isNot(contains('-ss')));
            expect(args, isNot(contains('-t')));
          }
          final runner = FfmpegJobRunnerService();
          final done = Completer<ConvertJob>();
          final updates = runner.onJobUpdate.listen((job) {
            if (job.id == jobs[i].id &&
                (job.status == .cleaning ||
                    job.status == .failed ||
                    job.status == .cancelled) &&
                !done.isCompleted) {
              done.complete(job);
            }
          });
          try {
            await runner.run(jobs[i]);
            expect(
              (await done.future.timeout(const Duration(seconds: 30))).status,
              JobStatus.cleaning,
            );
          } finally {
            await updates.cancel();
          }
          final info = await FFprobeKit.getMediaInformation(
            jobs[i].convertedFilePath,
          );
          expect(
            double.parse(info.getMediaInformation()!.getDuration()!),
            closeTo(i == 2 ? 3.0 : 1.0, 0.02),
          );
        }
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        await injector.unregister<JobConfigurationData>();
        // This test owns every job directory beneath this fixture cache.
        final convert = await injector<FileService>()
            .getConvertTemporaryDirectory(null);
        if (await convert.exists()) await convert.delete(recursive: true);
      }
    },
  );
}

Future<void> _execute(List<String> arguments) async {
  final session = await FFmpegKit.executeWithArguments(['-y', ...arguments]);
  expect(
    ReturnCode.isSuccess(await session.getReturnCode()),
    isTrue,
    reason: await session.getOutput(),
  );
}

Future<(int, int, int)> _pixel(String path, {double horizontal = 0.5}) async {
  final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
  final frame = await codec.getNextFrame();
  final data = (await frame.image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!;
  final index =
      ((frame.image.height ~/ 2) * frame.image.width +
          ((frame.image.width - 1) * horizontal).round()) *
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

Future<int> _waveHeight(String path, double horizontal) async {
  final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final column = ((image.width - 1) * horizontal).round();
  var height = 0;
  for (var row = 0; row < image.height; row++) {
    if (data.getUint8((row * image.width + column) * 4 + 3) > 200) height++;
  }
  image.dispose();
  codec.dispose();
  return height;
}

Future<void> _until(WidgetTester tester, bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(condition(), isTrue);
}

class _Files(final Directory cache) extends DirectFileService {
  Directory? previewCache;
  @override
  Future<Directory> getAppCacheDirectory() async => previewCache ?? cache;
  @override
  Future<Directory> getConvertTemporaryDirectory(String? jobId) async {
    final base = Directory('${cache.path}/convert');
    return (jobId == null ? base : Directory('${base.path}/$jobId')).create(
      recursive: true,
    );
  }
}

class _Settings implements SettingsBox {
  @override
  dynamic get(dynamic key, {required dynamic defaultValue}) => defaultValue;
  @override
  Future<void> put(dynamic key, dynamic value) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Configurations implements JobConfigurationData {
  @override
  dynamic get(dynamic key, {required dynamic defaultValue}) => defaultValue;
  @override
  Future<void> put(dynamic key, dynamic value) async {}
  @override
  Future<void> onDispose() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
