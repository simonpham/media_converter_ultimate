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
      model.setSelectedValue('configs.mp4.crf.x264', '28');
      expect(model.selectedPreset, isNull);
      expect(model.selectedValues['configs.mp4.crf.x264'], '28');
      await model.applyPreset(.highQualityVideo);
      model.resetConfigurations();
      expect(model.selectedPreset, isNull);
    },
  );

  test(
    'deselecting restores built-in defaults and preserves the file draft',
    () async {
      injector.registerSingleton<FileService>(TestMediaFiles());
      await model.addFiles([File('/source/movie.mkv')]);
      await model.applyPreset(.highQualityVideo);
      model.resetConfigurations();
      final defaults = {...model.selectedValues};
      model.selectedFormatEntry!.setLastKnownConfigurations({
        'configs.mp4.crf.x264': '28',
      });
      await model.applyPreset(.highQualityVideo);
      model.setOutputFileName('/source/movie.mkv', 'holiday.mp4');
      const trim = ConversionTrim(
        start: Duration(seconds: 1),
        end: Duration(seconds: 3),
      );
      model.setFileTrim(
        '/source/movie.mkv',
        const FileTrimResult(
          trim: trim,
          duration: Duration(seconds: 4),
        ),
      );
      final directory = model.outputDirectoryPath;
      model.clearPreset();
      expect(model.selectedPreset, isNull);
      expect(model.selectedFormatEntry!.name, 'mp4');
      expect(model.selectedValues, defaults);
      expect(model.selectedFiles.single.path, '/source/movie.mkv');
      expect(model.trimFor('/source/movie.mkv'), trim);
      expect(model.outputFileNames['/source/movie.mkv'], 'holiday.mp4');
      expect(model.outputDirectoryPath, directory);
      // Clearing an already custom draft does not discard further edits.
      model.setSelectedValue('configs.mp4.crf.x264', '18');
      model.clearPreset();
      expect(model.selectedValues['configs.mp4.crf.x264'], '18');
      model.loadPreviousConfigurations();
      expect(model.selectedPreset, isNull);
      expect(model.selectedValues['configs.mp4.crf.x264'], '28');
      model.resetConfigurations();
      expect(model.selectedValues, defaults);
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

  test('all audio defaults preserve silence and old truncating settings are repaired', () async {
    for (final format in model.formatConfigModel.formats.where(
      (format) => format.outputType == .audio,
    )) {
      await model.setSelectedFormatEntry(format);
      model.resetConfigurations();
      expect(model.selectedValues['configs.common.trim_silence'], '[]');
      final arguments = CommandBuilder.buildArgs(
        inputFilePath: 'source.wav',
        formatEntry: format,
        availableControls: model.availableControls,
        selectedValues: model.selectedValues,
        outputFilePath: 'output.${format.outputExtension}',
        threadCount: 1,
        configurationKeys: model.configControls.keys.toSet(),
      );
      expect(arguments, isNot(contains('-af')), reason: format.name);
    }
    final format = model.formatConfigModel.formats.firstWhere(
      (format) => format.name == 'mp3',
    );
    format.setLastKnownConfigurations({
      'configs.mp3.audio_encoder': 'libmp3lame',
      'configs.mp3.bitrate_type': 'configs.mp3.bitrate_type.cbr.value',
      'configs.mp3.bitrate': '320k',
      'configs.common.trim_silence': jsonEncode([
        '-af silenceremove=start_periods=1:start_duration=0:start_threshold=-50dB:stop_periods=1:stop_duration=1:stop_threshold=-50dB',
      ]),
    });
    await model.setSelectedFormatEntry(format);
    expect(model.selectedValues['configs.common.trim_silence'], '[]');
    expect(model.selectedValues['configs.mp3.bitrate'], '320k');
  });

  test(
    'silence removal is optional and retains audio after a long pause',
    () async {
      final directory = await Directory.systemTemp.createTemp('mcu-silence-');
      addTearDown(() => directory.delete(recursive: true));
      final source = '${directory.path}/source.wav';
      await runFfmpeg([
        '-f',
        'lavfi',
        '-i',
        r'aevalsrc=if(between(t\,0.5\,1)\,0.2*sin(2*PI*440*t)\,if(between(t\,2.5\,3.5)\,0.2*sin(2*PI*880*t)\,0)):s=48000:d=4',
        '-c:a',
        'pcm_s16le',
        source,
      ]);
      await model.setSelectedFormatEntry(
        model.formatConfigModel.formats.firstWhere(
          (format) => format.name == 'm4a',
        ),
      );
      model.resetConfigurations();
      model.setSelectedValue(
        'configs.m4a.audio_encoder',
        'configs.m4a.audio_encoder.value.alac',
      );
      final original = await decodedPcm(source);
      for (final enabled in [false, true]) {
        if (enabled) {
          final control = model.availableControls.singleWhere(
            (control) => control.name == 'configs.common.trim_silence',
          );
          model.setSelectedValue(
            control.name,
            jsonEncode([control.options.single.value]),
          );
        }
        final output = '${directory.path}/edited-$enabled.m4a';
        await runFfmpeg(
          CommandBuilder.buildArgs(
            inputFilePath: source,
            formatEntry: model.selectedFormatEntry!,
            availableControls: model.availableControls,
            selectedValues: model.selectedValues,
            outputFilePath: output,
            threadCount: 1,
            configurationKeys: model.configControls.keys.toSet(),
          ),
        );
        final pcm = await decodedPcm(output);
        if (!enabled) {
          expect(pcm, original);
        } else {
          expect(pcm.length, greaterThan(48000 * 2 * 1.4));
          expect(pcm.length, lessThan(48000 * 2 * 3.25));
          final laterTone = original.sublist(
            48000 * 2 * 3,
            48000 * 2 * 3 + 4800,
          );
          expect(latin1.decode(pcm).contains(latin1.decode(laterTone)), isTrue);
        }
      }
    },
  );

  test('compatible video uses 8-bit output for a 10-bit source', () async {
    final directory = await Directory.systemTemp.createTemp('mcu-bit-depth-');
    addTearDown(() => directory.delete(recursive: true));
    final source = '${directory.path}/source.mkv';
    await runFfmpeg([
      '-f',
      'lavfi',
      '-i',
      'testsrc2=size=128x96:rate=8:duration=1',
      '-pix_fmt',
      'yuv420p10le',
      '-c:v',
      'ffv1',
      source,
    ]);
    for (final depth in ['-pix_fmt yuv420p', '[]', '-pix_fmt yuv420p10le']) {
      await model.applyPreset(.compatibleVideo);
      if (depth != '-pix_fmt yuv420p') {
        model.setSelectedValue('configs.mp4.pixel_format.x264', depth);
      }
      final output = '${directory.path}/depth-${depth.length}.mp4';
      await runFfmpeg(
        CommandBuilder.buildArgs(
          inputFilePath: source,
          formatEntry: model.selectedFormatEntry!,
          availableControls: model.availableControls,
          selectedValues: model.selectedValues,
          outputFilePath: output,
          threadCount: 1,
          configurationKeys: model.configControls.keys.toSet(),
        ),
      );
      final probe = await Process.run('ffprobe', [
        '-v',
        'error',
        '-show_streams',
        '-of',
        'json',
        output,
      ]);
      expect(probe.exitCode, 0, reason: probe.stderr.toString());
      final stream =
          (jsonDecode(probe.stdout as String)['streams'] as List).single;
      expect(stream['codec_name'], 'h264');
      expect(
        stream['pix_fmt'],
        depth == '-pix_fmt yuv420p' ? 'yuv420p' : 'yuv420p10le',
      );
    }
  });

  test(
    'MP3 converts to audio-only MP4 with defaults and video presets',
    () async {
      final directory = await Directory.systemTemp.createTemp('mcu-audio-mp4-');
      addTearDown(() => directory.delete(recursive: true));
      final source = '${directory.path}/music.mp3';
      await runFfmpeg([
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=440:sample_rate=48000:duration=2',
        '-c:a',
        'libmp3lame',
        '-metadata',
        'title=Audio-only source',
        source,
      ]);
      final cover = '${directory.path}/cover.png';
      await runFfmpeg([
        '-f',
        'lavfi',
        '-i',
        'color=size=32x32:duration=0.1',
        '-frames:v',
        '1',
        cover,
      ]);
      final artworkSource = '${directory.path}/music-art.mp3';
      await runFfmpeg([
        '-i',
        source,
        '-i',
        cover,
        '-map',
        '0:a',
        '-map',
        '1:v',
        '-c',
        'copy',
        '-disposition:v',
        'attached_pic',
        artworkSource,
      ]);
      for (final (index, input) in [source, artworkSource].indexed) {
        for (final preset in <ConversionPreset?>[
          null,
          .compatibleVideo,
          .smallerVideo,
          .highQualityVideo,
        ]) {
          if (preset == null) {
            await model.setSelectedFormatEntry(
              model.formatConfigModel.formats.firstWhere(
                (format) => format.name == 'mp4',
              ),
            );
            model.resetConfigurations();
          } else {
            await model.applyPreset(preset);
          }
          final output =
              '${directory.path}/$index-${preset?.name ?? 'default'}.mp4';
          await runFfmpeg(
            CommandBuilder.buildArgs(
              inputFilePath: input,
              formatEntry: model.selectedFormatEntry!,
              availableControls: model.availableControls,
              selectedValues: model.selectedValues,
              outputFilePath: output,
              threadCount: 1,
              configurationKeys: model.configControls.keys.toSet(),
            ),
          );
          final probe = await Process.run('ffprobe', [
            '-v',
            'error',
            '-show_streams',
            '-show_format',
            '-of',
            'json',
            output,
          ]);
          expect(probe.exitCode, 0, reason: probe.stderr.toString());
          final media = jsonDecode(probe.stdout as String);
          final stream = (media['streams'] as List).single;
          expect(stream['codec_type'], 'audio');
          expect(stream['codec_name'], 'aac');
          expect(double.parse(media['format']['duration']), closeTo(2, 0.1));
          expect(media['format']['tags']['title'], 'Audio-only source');
        }
      }
    },
  );

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
      for (final (input, trim) in [
        (source, null),
        (movie, null),
        (
          source,
          const ConversionTrim(
            start: Duration(milliseconds: 50),
            end: Duration(milliseconds: 150),
          ),
        ),
        (
          movie,
          const ConversionTrim(
            start: Duration(milliseconds: 50),
            end: Duration(milliseconds: 150),
          ),
        ),
      ]) {
        final output =
            '${temporary.path}/${preset.name}-${input == source ? 'art' : 'video'}-${trim == null ? 'full' : 'trim'}.${preset.formatName}';
        await runFfmpeg(
          CommandBuilder.buildArgs(
            inputFilePath: input,
            formatEntry: model.selectedFormatEntry!,
            availableControls: model.availableControls,
            selectedValues: model.selectedValues,
            outputFilePath: output,
            threadCount: 0,
            configurationKeys: model.configControls.keys.toSet(),
            trim: trim,
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
    'trimmed lossless audio matches exactly the requested source samples',
    () async {
      final directory = await Directory.systemTemp.createTemp('mcu-trim-');
      addTearDown(() => directory.delete(recursive: true));
      final source = '${directory.path}/source.wav';
      final output = '${directory.path}/trimmed.m4a';
      await runFfmpeg([
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=440:sample_rate=48000:duration=3',
        '-c:a',
        'pcm_s16le',
        source,
      ]);
      await model.applyPreset(.losslessAudio);
      injector.registerSingleton<FileService>(TestMediaFiles());
      await model.addFiles([File(source)]);
      model.setFileTrim(
        source,
        const FileTrimResult(
          duration: Duration(seconds: 3),
          trim: ConversionTrim(
            start: Duration(milliseconds: 750),
            end: Duration(milliseconds: 1750),
          ),
        ),
      );
      final args = CommandBuilder.buildArgs(
        inputFilePath: source,
        formatEntry: model.selectedFormatEntry!,
        availableControls: model.availableControls,
        selectedValues: model.selectedValues,
        outputFilePath: output,
        threadCount: 0,
        configurationKeys: model.configControls.keys.toSet(),
        trim: model.trimFor(source),
      );
      await runFfmpeg(args);
      final originalPcm = await decodedPcm(source);
      final trimmedPcm = await decodedPcm(output);
      // Mono, signed 16-bit PCM at 48 kHz: two bytes per sample.
      const startOffset = 48000 * 2 * 750 ~/ 1000;
      const length = 48000 * 2;
      expect(
        trimmedPcm,
        originalPcm.sublist(startOffset, startOffset + length),
      );
      expect(ConversionTrim.fromArguments(args)?.effectiveDuration(3000), 1000);
    },
  );

  test(
    'GIF converts video with audio using only the first video track',
    () async {
      final directory = await Directory.systemTemp.createTemp('mcu-gif-');
      addTearDown(() => directory.delete(recursive: true));
      final source = '${directory.path}/source.mkv';
      final output = '${directory.path}/output.gif';
      await runFfmpeg([
        '-f',
        'lavfi',
        '-i',
        'testsrc2=size=128x96:rate=8:duration=0.5',
        '-f',
        'lavfi',
        '-i',
        'sine=duration=0.5',
        '-c:v',
        'libx264',
        '-c:a',
        'pcm_s16le',
        source,
      ]);
      await model.setSelectedFormatEntry(
        model.formatConfigModel.formats.firstWhere(
          (format) => format.name == 'gif',
        ),
      );
      await runFfmpeg(
        CommandBuilder.buildArgs(
          inputFilePath: source,
          formatEntry: model.selectedFormatEntry!,
          availableControls: model.availableControls,
          selectedValues: model.selectedValues,
          outputFilePath: output,
          threadCount: 1,
          configurationKeys: model.configControls.keys.toSet(),
        ),
      );
      final probe = await Process.run('ffprobe', [
        '-v',
        'error',
        '-show_streams',
        '-of',
        'json',
        output,
      ]);
      expect(probe.exitCode, 0, reason: probe.stderr.toString());
      final streams = (jsonDecode(probe.stdout as String)['streams'] as List)
          .cast<Map<String, dynamic>>();
      expect(streams, hasLength(1));
      expect(streams.single['codec_name'], 'gif');
      expect(streams.single['codec_type'], 'video');
    },
  );

  test('video trim keeps matching audio and video durations', () async {
    final directory = await Directory.systemTemp.createTemp('mcu-video-trim-');
    addTearDown(() => directory.delete(recursive: true));
    final source = '${directory.path}/source.mkv';
    final output = '${directory.path}/trimmed.mp4';
    await runFfmpeg([
      '-f',
      'lavfi',
      '-i',
      'testsrc2=size=320x240:rate=24:duration=3',
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=440:duration=3',
      '-c:v',
      'libx264',
      '-c:a',
      'pcm_s16le',
      source,
    ]);
    await model.applyPreset(.compatibleVideo);
    await runFfmpeg(
      CommandBuilder.buildArgs(
        inputFilePath: source,
        formatEntry: model.selectedFormatEntry!,
        availableControls: model.availableControls,
        selectedValues: model.selectedValues,
        outputFilePath: output,
        threadCount: 0,
        configurationKeys: model.configControls.keys.toSet(),
        trim: const ConversionTrim(
          start: Duration(seconds: 1),
          end: Duration(seconds: 2),
        ),
      ),
    );
    final probe = await Process.run('ffprobe', [
      '-v',
      'error',
      '-show_streams',
      '-of',
      'json',
      output,
    ]);
    expect(probe.exitCode, 0, reason: probe.stderr.toString());
    final streams = (jsonDecode(probe.stdout as String)['streams'] as List)
        .cast<Map<String, dynamic>>();
    expect(streams, hasLength(2));
    for (final stream in streams) {
      expect(double.parse(stream['duration']), closeTo(1, 0.05));
      expect(double.parse(stream['start_time']), closeTo(0, 0.05));
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
