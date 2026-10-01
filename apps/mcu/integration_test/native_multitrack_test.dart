import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:converter/converter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:platform_utils/platform_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late String source;
  late String bitmapSource;
  late JobMakerViewModel model;

  setUpAll(() async {
    injector.registerSingleton<FileService>(DirectFileService());
    injector.registerSingleton<SettingsBox>(_Settings());
    injector.registerSingleton<JobConfigurationData>(_Configurations());
    final cache = await injector<FileService>().getAppCacheDirectory();
    directory = await cache.createTemp('native_multitrack_qa_');
    source = '${directory.path}/two audio tracks.mkv';
    final subtitles = '${directory.path}/captions.srt';
    await File(subtitles).writeAsString(
      '1\n00:00:00,100 --> 00:00:01,900\nSubtitle QA – Xin chào Việt Nam\n',
    );
    await _execute([
      '-f',
      'lavfi',
      '-i',
      'testsrc2=size=128x96:rate=8:duration=2',
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=440:sample_rate=48000:duration=2',
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=880:sample_rate=48000:duration=2',
      '-i',
      subtitles,
      '-map',
      '0:v',
      '-map',
      '1:a',
      '-map',
      '2:a',
      '-map',
      '3:s',
      '-c:v',
      'libx264',
      '-colorspace',
      'bt709',
      '-preset',
      'ultrafast',
      '-c:a',
      'pcm_s16le',
      '-c:s',
      'srt',
      '-disposition:a:0',
      '0',
      '-disposition:a:1',
      'default',
      '-metadata:s:a:0',
      'language=eng',
      '-metadata:s:a:1',
      'language=vie',
      '-metadata:s:s:0',
      'language=eng',
      source,
    ]);
    final bitmap = '${directory.path}/owned rectangle.sup';
    await File(bitmap).writeAsBytes(_bitmapSubtitle());
    bitmapSource = '${directory.path}/text and bitmap subtitles.mkv';
    await _execute([
      '-i',
      source,
      '-i',
      bitmap,
      '-map',
      '0',
      '-map',
      '1:s',
      '-c',
      'copy',
      '-metadata:s:s:1',
      'language=vie',
      bitmapSource,
    ]);
    model = JobMakerViewModel(
      formatConfigModel: FormatConfigModel.fromJson(
        jsonDecode(await rootBundle.loadString('assets/configs/format.json')),
      ),
      translations: const {},
    );
  });

  tearDownAll(() async {
    model.dispose();
    await directory.delete(recursive: true);
    await injector.reset();
  });

  for (final format in ['mp3', 'wav', 'aac', 'flac']) {
    testWidgets('$format extracts one default audio track', (_) async {
      final output = await _convert(model, directory, source, format);
      final media = await _probe(output);
      final streams = (media['streams'] as List).cast<Map>();
      expect(
        streams.where((stream) => stream['codec_type'] == 'audio'),
        hasLength(1),
      );
      expect(streams.any((stream) => stream['codec_type'] == 'video'), isFalse);
      if (format == 'wav') {
        final reference = '${directory.path}/reference.wav';
        await _execute([
          '-i',
          source,
          '-map',
          '0:a:1',
          '-c:a',
          'pcm_s24le',
          '-ac',
          '2',
          '-ar',
          '48000',
          reference,
        ]);
        final actual = await _pcm(output, directory, 'actual');
        final expected = await _pcm(reference, directory, 'expected');
        expect(
          actual,
          expected,
          reason: 'The flagged default track is the second track',
        );
      }
    });
  }

  for (final (format, codec) in [
    ('mp4', 'mov_text'),
    ('mov', 'mov_text'),
    ('mkv', 'subrip'),
    ('webm', 'webvtt'),
  ]) {
    testWidgets(
      '$format retains both audio tracks and compatible text subtitles',
      (_) async {
        final output = await _convert(model, directory, source, format);
        final media = await _probe(output);
        final streams = (media['streams'] as List).cast<Map>();
        final audio = streams
            .where((stream) => stream['codec_type'] == 'audio')
            .toList();
        expect(audio, hasLength(2));
        expect(audio.map((stream) => stream['tags']?['language']), [
          'eng',
          'vie',
        ]);
        final subtitles = streams
            .where((stream) => stream['codec_type'] == 'subtitle')
            .single;
        expect(subtitles['codec_name'], codec);
        expect(subtitles['tags']?['language'], 'eng');
      },
    );
  }
  for (final (format, keepBitmap) in [
    ('mp4', false),
    ('webm', false),
    ('mkv', true),
    ('ts', false),
  ]) {
    testWidgets(
      '$format handles bitmap subtitles according to container support',
      (_) async {
        final output = await _convert(model, directory, bitmapSource, format);
        final streams = ((await _probe(output))['streams'] as List).cast<Map>();
        final subtitles = streams
            .where((stream) => stream['codec_type'] == 'subtitle')
            .toList();
        final bitmapIndex = subtitles.indexWhere(
          (stream) => stream['codec_name'] == 'hdmv_pgs_subtitle',
        );
        expect(bitmapIndex >= 0, keepBitmap);
        if (keepBitmap) {
          final decoded = await FFprobeKit.executeWithArguments([
            '-v',
            'error',
            '-select_streams',
            's:$bitmapIndex',
            '-show_frames',
            '-of',
            'json',
            output,
          ]);
          expect(ReturnCode.isSuccess(await decoded.getReturnCode()), isTrue);
          final frames =
              (jsonDecode((await decoded.getOutput())!)['frames'] as List)
                  .cast<Map>();
          expect(
            frames.any((frame) => frame['num_rects'] == 1),
            isTrue,
            reason: 'The copied owned rectangle must still decode as a bitmap subtitle',
          );
        }
      },
    );
  }

  testWidgets('TS retains decodable DVB bitmap subtitles', (_) async {
    final dvbSource = '${directory.path}/owned DVB subtitles.mkv';
    await _execute([
      '-fix_sub_duration',
      '-i',
      bitmapSource,
      '-map',
      '0:v',
      '-map',
      '0:a',
      '-map',
      '0:s:1',
      '-c:v',
      'copy',
      '-c:a',
      'copy',
      '-c:s',
      'dvbsub',
      dvbSource,
    ]);
    final output = await _convert(model, directory, dvbSource, 'ts');
    final streams = ((await _probe(output))['streams'] as List).cast<Map>();
    final subtitles = streams
        .where((stream) => stream['codec_type'] == 'subtitle')
        .toList();
    expect(subtitles.single['codec_name'], 'dvb_subtitle');
    final decoded = await FFprobeKit.executeWithArguments([
      '-v',
      'error',
      '-select_streams',
      's',
      '-show_frames',
      '-of',
      'json',
      output,
    ]);
    expect(ReturnCode.isSuccess(await decoded.getReturnCode()), isTrue);
    final frames = (jsonDecode((await decoded.getOutput())!)['frames'] as List)
        .cast<Map>();
    expect(
      frames.any((frame) => (frame['num_rects'] as int? ?? 0) > 0),
      isTrue,
    );
  });

  for (final inputFormat in ['mp4', 'webm']) {
    testWidgets(
      '$inputFormat subtitles remain readable after converting to MKV',
      (_) async {
        final intermediate = await _convert(
          model,
          directory,
          source,
          inputFormat,
        );
        final output = await _convert(model, directory, intermediate, 'mkv');
        final captions = '${directory.path}/roundtrip-$inputFormat.srt';
        await _execute([
          '-i',
          output,
          '-map',
          '0:s:0',
          '-c:s',
          'srt',
          captions,
        ]);
        expect(
          await File(captions).readAsString(),
          contains('Subtitle QA – Xin chào Việt Nam'),
        );
      },
    );
  }

  testWidgets(
    'all 25 defaults accept a source with multiple audio and subtitle tracks',
    (_) async {
      final failures = <String>[];
      for (final entry in model.formatConfigModel.formats) {
        try {
          final output = await _convert(
            model,
            directory,
            bitmapSource,
            entry.name,
          );
          expect((await _probe(output))['streams'], isNotEmpty);
          await _execute([
            '-xerror',
            '-i',
            output,
            '-map',
            '0:V?',
            '-map',
            '0:a?',
            '-sn',
            '-f',
            'null',
            '-',
          ]);
          expect(await File(output).length(), greaterThan(0));
          printLog('[Multi-track QA] ${entry.name}: passed');
        } catch (error) {
          failures.add('${entry.name}: $error');
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    },
  );
}

var _conversionNumber = 0;

Future<String> _convert(
  JobMakerViewModel model,
  Directory directory,
  String source,
  String format,
) async {
  await model.setSelectedFormatEntry(
    model.formatConfigModel.formats.singleWhere(
      (entry) => entry.name == format,
    ),
  );
  model.resetConfigurations();
  final entry = model.selectedFormatEntry!;
  final number = ++_conversionNumber;
  final output = '${directory.path}/converted-$number.${entry.outputExtension}';
  final arguments = CommandBuilder.buildArgs(
    inputFilePath: source,
    formatEntry: entry,
    availableControls: model.availableControls,
    selectedValues: model.selectedValues,
    outputFilePath: output,
    threadCount: 1,
    configurationKeys: model.configControls.keys.toSet(),
  );
  final now = DateTime.now();
  final job = ConvertJob(
    id: 'multitrack-$format-$number',
    inputFilePath: source,
    outputFileName: 'converted.${entry.outputExtension}',
    outputExtension: entry.outputExtension,
    outputDirectoryPath: directory.path,
    convertedFilePath: output,
    command: jsonEncode(arguments),
    createdAt: now,
    updatedAt: now,
  );
  final runner = FfmpegJobRunnerService();
  final completed = Completer<ConvertJob>();
  final subscription = runner.onJobUpdate.listen((event) {
    if ((event.status == .cleaning || event.status.isDone) &&
        !completed.isCompleted) {
      completed.complete(event);
    }
  });
  try {
    await runner.run(job);
    final terminal = await completed.future.timeout(
      const Duration(seconds: 30),
    );
    final sessions = await FFmpegKit.listSessions();
    final native = sessions.singleWhere(
      (session) => session.getSessionId() == terminal.sessionId,
    );
    expect(
      terminal.status,
      JobStatus.cleaning,
      reason: await native.getAllLogsAsString(),
    );
    return output;
  } finally {
    await subscription.cancel();
    final temporary = await injector<FileService>()
        .getConvertTemporaryDirectory(job.id);
    if (await temporary.exists()) await temporary.delete(recursive: true);
  }
}

Future<void> _execute(List<String> arguments) async {
  final session = await FFmpegKit.executeWithArguments([
    '-y',
    '-loglevel',
    'error',
    ...arguments,
  ]);
  expect(
    ReturnCode.isSuccess(await session.getReturnCode()),
    isTrue,
    reason: await session.getAllLogsAsString(),
  );
}

Future<Map<dynamic, dynamic>> _probe(String path) async {
  final session = await FFprobeKit.getMediaInformation(path);
  expect(ReturnCode.isSuccess(await session.getReturnCode()), isTrue);
  return session.getMediaInformation()!.getAllProperties()!;
}

Future<List<int>> _pcm(
  String path,
  Directory directory,
  String name, {
  int audioIndex = 0,
}) async {
  final output = '${directory.path}/$name.pcm';
  await _execute([
    '-i',
    path,
    '-map',
    '0:a:$audioIndex',
    '-ac',
    '1',
    '-ar',
    '48000',
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

/// Own PGS fixture: a 64 × 16 white rectangle, displayed from 0.1 to 1.9 seconds.
/// Segment layout is checked against FFmpeg's pgssubdec.c; no media is downloaded.
List<int> _bitmapSubtitle() {
  final bytes = BytesBuilder();
  void segment(int type, int pts, List<int> payload) {
    final header = ByteData(13)
      ..setUint16(0, 0x5047)
      ..setUint32(2, pts)
      ..setUint32(6, 0)
      ..setUint8(10, type)
      ..setUint16(11, payload.length);
    bytes.add(header.buffer.asUint8List());
    bytes.add(payload);
  }

  const start = 9000;
  segment(0x16, start, [
    0,
    128,
    0,
    96,
    0x10,
    0,
    0,
    0x80,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    8,
    0,
    24,
  ]);
  segment(0x17, start, [1, 0, 0, 8, 0, 24, 0, 64, 0, 16]);
  segment(0x14, start, [0, 0, 0, 16, 128, 128, 0, 1, 235, 128, 128, 255]);
  final rle = [
    for (var row = 0; row < 16; row++) ...[0, 0xc0, 64, 1, 0, 0],
  ];
  segment(0x15, start, [
    0,
    0,
    0,
    0xc0,
    0,
    0,
    rle.length + 4,
    0,
    64,
    0,
    16,
    ...rle,
  ]);
  segment(0x80, start, []);
  segment(0x16, 171000, [0, 128, 0, 96, 0x10, 0, 1, 0, 0, 0, 0]);
  segment(0x80, 171000, []);
  return bytes.takeBytes();
}
