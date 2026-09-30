import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:converter/converter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:platform_utils/platform_utils.dart'
    show
        DirectFileService,
        FFmpegKit,
        FFprobeKit,
        FileService,
        ReturnCode,
        SessionState;

/// Runs against the bundled Android engine, rather than the host FFmpeg CLI.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late String audio;
  late String video;
  late JobMakerViewModel model;

  setUpAll(() async {
    injector.registerSingleton<SettingsBox>(_Settings());
    injector.registerSingleton<JobConfigurationData>(_Configurations());
    injector.registerSingleton<FileService>(DirectFileService());
    final cache = await injector<FileService>().getAppCacheDirectory();
    directory = await cache.createTemp('native_release_qa_');
    audio = '${directory.path}/source Việt "music".wav';
    video = '${directory.path}/source video.mkv';
    model = JobMakerViewModel(
      formatConfigModel: FormatConfigModel.fromJson(
        jsonDecode(await rootBundle.loadString('assets/configs/format.json')),
      ),
      translations: const {},
    );
    await _execute([
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=440:sample_rate=48000:duration=2',
      '-c:a',
      'pcm_s16le',
      '-metadata',
      'title=Native QA',
      audio,
    ]);
    await _execute([
      '-f',
      'lavfi',
      '-i',
      'testsrc2=size=128x96:rate=8:duration=2',
      '-i',
      audio,
      '-c:v',
      'libx264',
      '-preset',
      'ultrafast',
      '-c:a',
      'pcm_s16le',
      '-metadata',
      'title=Native QA',
      video,
    ]);
  });

  tearDownAll(() async {
    model.dispose();
    await directory.delete(recursive: true);
    await injector.reset();
  });

  testWidgets('every shipped format default converts on Android', (_) async {
    final failures = <String>[];
    for (final format in model.formatConfigModel.formats) {
      await model.setSelectedFormatEntry(format);
      model.resetConfigurations();
      final output = '${directory.path}/default.${format.outputExtension}';
      try {
        await _execute(
          _arguments(
            model,
            format.outputType == .audio ? audio : video,
            output,
          ),
        );
        final media = await _probe(output);
        expect(media['streams'], isNotEmpty, reason: format.name);
        expect(await File(output).length(), greaterThan(0));
        printLog('[Native QA] default ${format.name}: passed');
      } catch (error) {
        failures.add('${format.name}: $error');
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  testWidgets('presets and precise lossless trim use native codecs', (_) async {
    for (final preset in ConversionPreset.values) {
      await model.applyPreset(preset);
      final output = '${directory.path}/${preset.name}.${preset.formatName}';
      await _execute(
        _arguments(
          model,
          preset.formatName == 'mp4' ? video : audio,
          output,
        ),
      );
      final media = await _probe(output);
      final streams = (media['streams'] as List).cast<Map<dynamic, dynamic>>();
      final audioStream = streams.firstWhere((s) => s['codec_type'] == 'audio');
      expect(audioStream['codec_name'], switch (preset) {
        .musicMp3 => 'mp3',
        .losslessAudio => 'alac',
        _ => 'aac',
      });
      expect(double.parse(media['format']['duration']), closeTo(2, 0.1));
      expect(media['format']['tags']['title'], 'Native QA');
      if (preset == .musicMp3) expect(audioStream['bit_rate'], '320000');
      if (preset == .losslessAudio) {
        expect(audioStream['sample_rate'], '48000');
        expect(audioStream['channels'], 1);
        expect(await _pcm(output, directory), await _pcm(audio, directory));
      }
      printLog('[Native QA] preset ${preset.name}: passed');
    }
    await model.applyPreset(.losslessAudio);
    final output = '${directory.path}/trimmed.m4a';
    await _execute(
      _arguments(
        model,
        audio,
        output,
        trim: const ConversionTrim(
          start: Duration(milliseconds: 750),
          end: Duration(milliseconds: 1750),
        ),
      ),
    );
    final original = await _pcm(audio, directory);
    expect(await _pcm(output, directory), original.sublist(72000, 168000));
  });

  testWidgets('native audio conversion preserves covers through trimming', (
    _,
  ) async {
    final cover = '${directory.path}/cover.jpg';
    final lossless = '${directory.path}/cover-audio.m4a';
    final source = '${directory.path}/with-cover.m4a';
    await _execute([
      '-f',
      'lavfi',
      '-i',
      'color=c=blue:size=32x32:duration=0.1',
      '-frames:v',
      '1',
      cover,
    ]);
    await _execute(['-i', audio, '-c:a', 'alac', lossless]);
    await _execute([
      '-i',
      lossless,
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
      source,
    ]);
    final sourceMedia = await _probe(source);
    expect(
      (sourceMedia['streams'] as List).where(
        (dynamic stream) => stream['disposition']['attached_pic'] == 1,
      ),
      hasLength(1),
    );
    for (final preset in <ConversionPreset>[
      .musicMp3,
      .compactAudio,
      .losslessAudio,
    ]) {
      await model.applyPreset(preset);
      for (final input in [source, video]) {
        final output =
            '${directory.path}/cover-${preset.name}.${preset.formatName}';
        await _execute(
          _arguments(
            model,
            input,
            output,
            trim: const ConversionTrim(
              start: Duration(milliseconds: 500),
              end: Duration(milliseconds: 1500),
            ),
          ),
        );
        final media = await _probe(output);
        final streams = (media['streams'] as List)
            .cast<Map<dynamic, dynamic>>();
        final pictures = streams.where((s) => s['codec_type'] == 'video');
        expect(
          pictures,
          hasLength(input == source ? 1 : 0),
          reason: '${preset.name}, source=$input, media=${jsonEncode(media)}',
        );
        if (pictures.isNotEmpty) {
          expect(pictures.single['disposition']['attached_pic'], 1);
          expect(pictures.single['codec_name'], 'mjpeg');
        }
        expect(double.parse(media['format']['duration']), closeTo(1, 0.1));
      }
    }
  });

  testWidgets('native runner rejects a trim beyond the source', (_) async {
    await model.applyPreset(.losslessAudio);
    final output = '${directory.path}/empty-range.m4a';
    final now = DateTime.now();
    final job = ConvertJob(
      id: 'native_qa_empty_range',
      inputFilePath: audio,
      outputFileName: 'empty-range.m4a',
      outputExtension: 'm4a',
      outputDirectoryPath: directory.path,
      command: jsonEncode(
        _arguments(
          model,
          audio,
          output,
          trim: const ConversionTrim(
            start: Duration(seconds: 3),
            end: Duration(seconds: 4),
          ),
        ),
      ),
      convertedFilePath: output,
      createdAt: now,
      updatedAt: now,
    );
    await expectLater(
      FfmpegJobRunnerService().run(job),
      throwsA(isA<EmptyTrimRangeFailure>()),
    );
    expect(await File(output).exists(), isFalse);
  });

  testWidgets(
    'the runner confirms immediate cancellation and shares requests',
    (_) async {
      final runner = FfmpegJobRunnerService();
      final updates = <ConvertJob>[];
      final subscription = runner.onJobUpdate.listen(updates.add);
      try {
        for (var iteration = 0; iteration < 5; iteration++) {
          final completed = Completer<void>();
          final session = await FFmpegKit.executeWithArgumentsAsync([
            '-re',
            '-f',
            'lavfi',
            '-i',
            'sine=duration=60',
            '-f',
            'null',
            '-',
          ], (_) => completed.complete());
          final now = DateTime.now();
          final job = ConvertJob(
            id: 'native_cancel_$iteration',
            inputFilePath: audio,
            outputFileName: 'cancel.mp3',
            outputExtension: 'mp3',
            outputDirectoryPath: directory.path,
            command: '[]',
            convertedFilePath: '${directory.path}/cancel.mp3',
            createdAt: now,
            updatedAt: now,
            sessionId: session.getSessionId(),
            status: .running,
          );
          final first = runner.stop(job);
          final second = runner.stop(job);
          expect(identical(first, second), isTrue);
          expect(await Future.wait([first, second]), [true, true]);
          await completed.future.timeout(const Duration(seconds: 15));
          expect(await session.getState(), SessionState.completed);
          expect(ReturnCode.isCancel(await session.getReturnCode()), isTrue);
          expect(
            await runner.getStatus('${session.getSessionId()}'),
            JobStatus.cancelled,
          );
          await Future<void>.delayed(Duration.zero);
          expect(
            updates.where((update) => update.id == job.id).single.status,
            JobStatus.cancelled,
          );
          expect(
            await runner.stop(job.copyWith(sessionId: const .new(999999))),
            isFalse,
          );
          expect(updates.where((update) => update.id == job.id), hasLength(1));
        }
      } finally {
        await subscription.cancel();
      }
    },
  );

  testWidgets('native failure and cancellation retain return codes', (_) async {
    final failed = await FFmpegKit.executeWithArguments([
      '-i',
      '${directory.path}/missing.wav',
      '${directory.path}/failed.mp3',
    ]);
    expect(ReturnCode.isSuccess(await failed.getReturnCode()), isFalse);
    expect(
      (await failed.getState()).toJobStatus(
        returnCode: await failed.getReturnCode(),
      ),
      JobStatus.failed,
    );
    final completed = Completer<void>();
    final running = Completer<void>();
    final session = await FFmpegKit.executeWithArgumentsAsync(
      [
        '-re',
        '-f',
        'lavfi',
        '-i',
        'sine=duration=60',
        '-f',
        'null',
        '-',
      ],
      (_) => completed.complete(),
      null,
      (_) {
        if (!running.isCompleted) running.complete();
      },
    );
    await running.future.timeout(const Duration(seconds: 15));
    await FFmpegKit.cancel(session.getSessionId());
    await completed.future.timeout(const Duration(seconds: 15));
    expect(ReturnCode.isCancel(await session.getReturnCode()), isTrue);
    expect(
      (await session.getState()).toJobStatus(
        returnCode: await session.getReturnCode(),
      ),
      JobStatus.cancelled,
    );
  });
}

List<String> _arguments(
  JobMakerViewModel model,
  String input,
  String output, {
  ConversionTrim? trim,
}) => CommandBuilder.buildArgs(
  inputFilePath: input,
  formatEntry: model.selectedFormatEntry!,
  availableControls: model.availableControls,
  selectedValues: model.selectedValues,
  outputFilePath: output,
  threadCount: 1,
  configurationKeys: model.configControls.keys.toSet(),
  trim: trim,
);

Future<void> _execute(List<String> args) async {
  var arguments = args;
  if (args.contains('0:v:disp:attached_pic?')) {
    final inputIndex = args.indexOf('-i');
    final media = await _probe(args[inputIndex + 1]);
    final streams = (media['streams'] as List).cast<Map<dynamic, dynamic>>();
    arguments = AudioArtworkMapping.resolve(
      args,
      attachedPictureIndexes: [
        for (final stream in streams)
          if (stream['disposition']['attached_pic'] == 1)
            stream['index'] as int,
      ],
    );
  }
  final session = await FFmpegKit.executeWithArguments([
    '-y',
    '-loglevel',
    'error',
    ...arguments,
  ]);
  expect(
    ReturnCode.isSuccess(await session.getReturnCode()),
    isTrue,
    reason: '${jsonEncode(args)}\n${await session.getAllLogsAsString()}',
  );
}

Future<Map<dynamic, dynamic>> _probe(String path) async {
  final session = await FFprobeKit.getMediaInformation(path);
  expect(ReturnCode.isSuccess(await session.getReturnCode()), isTrue);
  return session.getMediaInformation()!.getAllProperties()!;
}

Future<List<int>> _pcm(String path, Directory directory) async {
  final output = '${directory.path}/decoded.pcm';
  await _execute([
    '-i',
    path,
    '-map',
    '0:a:0',
    '-f',
    's16le',
    '-c:a',
    'pcm_s16le',
    output,
  ]);
  return File(output).readAsBytes();
}

class _Settings implements SettingsBox {
  @override
  dynamic get(dynamic key, {required dynamic defaultValue}) => defaultValue;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Configurations implements JobConfigurationData {
  @override
  Future<void> onDispose() async {}

  @override
  dynamic get(dynamic key, {required dynamic defaultValue}) => defaultValue;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
