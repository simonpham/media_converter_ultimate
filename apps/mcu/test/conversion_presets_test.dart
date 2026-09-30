import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:converter/converter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_utils/platform_utils.dart' show FileService;

import 'support/conversion_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late JobMakerViewModel model;

  setUp(() {
    injector.registerSingleton<SettingsBox>(MemorySettings());
    injector.registerSingleton<JobConfigurationData>(MemoryConfigurations());
    installShippedAssetHandler();
    model = JobMakerViewModel(
      formatConfigModel: loadShippedFormats(),
      translations: const {},
    );
  });

  tearDown(() async {
    model.dispose();
    clearShippedAssetHandler();
    await injector.reset();
  });

  test(
    'all advertised presets survive shipped configuration normalization',
    () async {
      expect(model.availablePresets, ConversionPreset.values);
      for (final preset in model.availablePresets) {
        await model.applyPreset(preset);
        expect(model.selectedPreset, preset);
        expect(model.selectedFormatEntry?.name, preset.formatName);
        for (final entry in preset.selectedValues.entries) {
          expect(
            model.selectedValues[entry.key],
            entry.value,
            reason: '${preset.name}: ${entry.key}',
          );
          expect(
            model.availableControls.any((control) => control.name == entry.key),
            isTrue,
          );
        }
      }
    },
  );

  test(
    'presets override remembered settings and editing clears the label',
    () async {
      final format = model.formatConfigModel.formats.firstWhere(
        (format) => format.name == 'mp4',
      );
      format.setLastKnownConfigurations({
        'configs.mp4.video_encoder': '-c:v libx265',
        'configs.mp4.crf.x264': '35',
      });
      await model.setSelectedFormatEntry(format);
      expect(model.selectedValues['configs.mp4.video_encoder'], '-c:v libx265');
      await model.applyPreset(.compatibleVideo);
      expect(model.selectedValues['configs.mp4.video_encoder'], '-c:v libx264');
      expect(model.selectedValues['configs.mp4.crf.x264'], '23');
      model.setSelectedValue('configs.mp4.crf.x264', '24');
      expect(model.selectedPreset, isNull);
      await model.applyPreset(.highQualityVideo);
      model.resetConfigurations();
      expect(model.selectedPreset, isNull);
    },
  );

  test('a slower preset load cannot replace the latest selection', () async {
    final delayed = Completer<void>();
    final loading = Completer<void>();
    installShippedAssetHandler(
      beforeLoad: (key) async {
        if (key.endsWith('/mp4.json')) {
          if (!loading.isCompleted) loading.complete();
          await delayed.future;
        }
      },
    );
    final first = model.applyPreset(.smallerVideo);
    await loading.future;
    expect(model.isLoadingFormat, isTrue);
    expect(model.checkError(.chooseOutputFormat), isA<NoOutputConfigFailure>());
    final second = model.applyPreset(.musicMp3);
    await second;
    expect(model.selectedPreset, ConversionPreset.musicMp3);
    delayed.complete();
    await first;
    expect(model.selectedPreset, ConversionPreset.musicMp3);
    expect(model.selectedFormatEntry?.name, 'mp3');
    expect(model.isLoadingFormat, isFalse);
  });

  test('repeated preset taps finish with matching output names', () async {
    injector.registerSingleton<FileService>(TestMediaFiles());
    await model.addFiles([File('/source/movie.mkv')]);
    await model.applyPreset(.compatibleVideo);
    model.setOutputFileName('/source/movie.mkv', 'holiday.mp4');
    await model.applyPreset(.smallerVideo);
    expect(model.outputFileNames['/source/movie.mkv'], 'holiday.mp4');
    final delayed = Completer<void>();
    final loading = Completer<void>();
    installShippedAssetHandler(
      beforeLoad: (key) async {
        if (key.endsWith('/mp3.json')) {
          if (!loading.isCompleted) loading.complete();
          await delayed.future;
        }
      },
    );
    final first = model.applyPreset(.musicMp3);
    await loading.future;
    final second = model.applyPreset(.musicMp3);
    delayed.complete();
    await Future.wait([first, second]);
    expect(model.selectedPreset, ConversionPreset.musicMp3);
    expect(model.outputFileNames['/source/movie.mkv'], 'movie.mp3');
  });

  test('all application locales include the preset and search strings', () {
    final directory = Directory(
      '${findRepository().path}/packages/l10n/lib/l10n',
    );
    final english = jsonDecode(
      File('${directory.path}/en.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    final keys = english.keys.where((key) => !key.startsWith('@')).toSet();
    for (final file in directory.listSync().whereType<File>().where(
      (file) => file.path.endsWith('.arb'),
    )) {
      final locale =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(keys.difference(locale.keys.toSet()), isEmpty, reason: file.path);
      for (final key in keys) {
        expect(locale[key], isA<String>(), reason: '${file.path}: $key');
        expect((locale[key] as String).trim(), isNotEmpty, reason: key);
      }
    }
  });

  test('format search accepts case, surrounding spaces, and extensions', () {
    model.setFormatQuery(' .MP4 ');
    expect(model.visibleFormats.map((format) => format.name), ['mp4']);
    model.setFormatQuery('3');
    expect(
      model.visibleFormats.map((format) => format.name),
      containsAll(['mp3', '3gp']),
    );
    model.setFormatQuery('no-such-format');
    expect(model.visibleFormats, isEmpty);
    model.setFormatQuery('');
    expect(model.visibleFormats, model.formatConfigModel.formats);
  });

  test('audio presets preserve embedded artwork without including full video', () async {
    final temporary = await Directory.systemTemp.createTemp('mcu-art-presets-');
    addTearDown(() => temporary.delete(recursive: true));
    final source = '${temporary.path}/art.m4a';
    final movie = '${temporary.path}/video.mkv';
    final audioSource = '${temporary.path}/audio.m4a';
    final artwork = '${temporary.path}/cover.jpg';
    await runFfmpeg([
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=440:duration=0.2',
      '-c:a',
      'alac',
      audioSource,
    ]);
    await runFfmpeg([
      '-f',
      'lavfi',
      '-i',
      'color=c=blue:size=32x32:duration=0.2',
      '-frames:v',
      '1',
      artwork,
    ]);
    await runFfmpeg([
      '-i',
      audioSource,
      '-i',
      artwork,
      '-map',
      '0:a:0',
      '-map',
      '1:v:0',
      '-c',
      'copy',
      '-disposition:v',
      'attached_pic',
      source,
    ]);
    await runFfmpeg([
      '-f',
      'lavfi',
      '-i',
      'testsrc2=size=32x32:duration=0.2',
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=440:duration=0.2',
      '-c:a',
      'pcm_s16le',
      '-c:v',
      'libx264',
      movie,
    ]);
    for (final preset in <ConversionPreset>[
      .musicMp3,
      .compactAudio,
      .losslessAudio,
    ]) {
      await model.applyPreset(preset);
      for (final input in [source, movie]) {
        final output =
            '${temporary.path}/${preset.name}-${input == source ? 'art' : 'video'}.${preset.formatName}';
        await runFfmpeg(
          CommandBuilder.buildArgs(
            inputFilePath: input,
            formatEntry: model.selectedFormatEntry!,
            availableControls: model.availableControls,
            selectedValues: model.selectedValues,
            outputFilePath: output,
            threadCount: 0,
            configurationKeys: model.configControls.keys.toSet(),
          ),
        );
        final result = await Process.run('ffprobe', [
          '-v',
          'error',
          '-show_streams',
          '-of',
          'json',
          output,
        ]);
        expect(result.exitCode, 0, reason: result.stderr.toString());
        final streams = (jsonDecode(result.stdout as String)['streams'] as List)
            .cast<Map<String, dynamic>>();
        expect(
          streams.where((stream) => stream['codec_type'] == 'audio'),
          hasLength(1),
        );
        final pictures = streams
            .where((stream) => stream['codec_type'] == 'video')
            .toList();
        expect(pictures, hasLength(input == source ? 1 : 0));
        if (pictures.isNotEmpty) {
          expect(pictures.single['disposition']['attached_pic'], 1);
          expect(pictures.single['codec_name'], 'mjpeg');
        }
      }
    }
  });

  test(
    'all preset commands execute and audio presets preserve the full track',
    () async {
      final temporary = await Directory.systemTemp.createTemp('mcu-presets-');
      addTearDown(() => temporary.delete(recursive: true));
      final audioPath = '${temporary.path}/source.wav';
      final videoPath = '${temporary.path}/source.mkv';
      await runFfmpeg([
        '-f',
        'lavfi',
        '-i',
        'aevalsrc=if(between(t\\,0.5\\,1.5)\\,0.1*sin(2*PI*440*t)\\,0)|if(between(t\\,0.5\\,1.5)\\,0.1*sin(2*PI*880*t)\\,0):s=44100:d=2',
        '-c:a',
        'pcm_s16le',
        '-metadata',
        'title=Preset source',
        audioPath,
      ]);
      await runFfmpeg([
        '-f',
        'lavfi',
        '-i',
        'testsrc2=size=320x240:rate=24:duration=2',
        '-i',
        audioPath,
        '-c:v',
        'libx264',
        '-c:a',
        'pcm_s16le',
        '-metadata',
        'title=Preset source',
        videoPath,
      ]);
      for (final preset in ConversionPreset.values) {
        await model.applyPreset(preset);
        final format = model.selectedFormatEntry!;
        final outputPath =
            '${temporary.path}/${preset.name}.${format.outputExtension}';
        final inputPath = preset.formatName == 'mp4' ? videoPath : audioPath;
        final command = CommandBuilder.buildCommand(
          inputFilePath: inputPath,
          formatEntry: format,
          availableControls: model.availableControls,
          selectedValues: model.selectedValues,
          outputFilePath: outputPath,
          threadCount: 0,
          configurationKeys: model.configControls.keys.toSet(),
        );
        final args = CommandBuilder.parseCommand(command);
        await runFfmpeg(args);
        final probe = await Process.run('ffprobe', [
          '-v',
          'error',
          '-show_streams',
          '-show_format',
          '-of',
          'json',
          outputPath,
        ]);
        expect(probe.exitCode, 0, reason: probe.stderr.toString());
        final media =
            jsonDecode(probe.stdout as String) as Map<String, dynamic>;
        final streams = (media['streams'] as List).cast<Map<String, dynamic>>();
        final audio = streams.firstWhere(
          (stream) => stream['codec_type'] == 'audio',
        );
        expect(audio['codec_name'], switch (preset) {
          .musicMp3 => 'mp3',
          .losslessAudio => 'alac',
          _ => 'aac',
        });
        expect(double.parse(media['format']['duration']), closeTo(2, 0.1));
        expect(media['format']['tags']['title'], 'Preset source');
        if (preset.formatName == 'mp4') {
          expect(
            streams.firstWhere(
              (stream) => stream['codec_type'] == 'video',
            )['codec_name'],
            'h264',
          );
          expect(
            args,
            containsAllInOrder([
              '-crf',
              switch (preset) {
                .compatibleVideo => '23',
                .smallerVideo => '28',
                _ => '18',
              },
            ]),
          );
        } else {
          expect(args, isNot(contains('-af')));
        }
        if (preset == .musicMp3) {
          expect(audio['bit_rate'], '320000');
          expect(args, isNot(contains('-q:a')));
        }
        if (preset == .compactAudio) {
          expect(args, containsAllInOrder(['-b:a', '128k']));
        }
        if (preset == .losslessAudio) {
          expect(audio['sample_rate'], '44100');
          expect(audio['channels'], 2);
          expect(args, isNot(contains('-ar')));
          expect(args, isNot(contains('-b:a')));
          expect(await decodedPcm(outputPath), await decodedPcm(audioPath));
        }
      }
    },
  );
}

Future<void> runFfmpeg(List<String> args) async {
  final result = await Process.run('ffmpeg', [
    '-hide_banner',
    '-loglevel',
    'error',
    ...args,
  ]);
  expect(result.exitCode, 0, reason: result.stderr.toString());
}

Future<List<int>> decodedPcm(String path) async {
  final result = await Process.run('ffmpeg', [
    '-v',
    'error',
    '-i',
    path,
    '-map',
    '0:a:0',
    '-f',
    's16le',
    '-c:a',
    'pcm_s16le',
    '-',
  ], stdoutEncoding: null);
  expect(result.exitCode, 0, reason: result.stderr.toString());
  return result.stdout as List<int>;
}
