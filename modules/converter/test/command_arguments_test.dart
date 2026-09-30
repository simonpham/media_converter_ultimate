import 'dart:convert';
import 'dart:io';

import 'package:converter/features/job_maker/utils/command_builder.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

const mp3 = FormatEntry(
  name: 'mp3',
  outputExtension: 'mp3',
  outputType: .audio,
  shouldAddToArgs: true,
);

void main() {
  test(
    'persisted arguments preserve quotes, spaces, slashes, and Unicode paths',
    () {
      const inputPath = '/media/"holiday" & \'music\' \\ \$song\nViệt Nam.wav';
      const outputPath =
          '/output/"holiday" & \'music\' \\ \$song\nViệt Nam.mp3';
      final command = CommandBuilder.buildCommand(
        inputFilePath: inputPath,
        formatEntry: mp3,
        availableControls: const [],
        selectedValues: const {},
        outputFilePath: outputPath,
        threadCount: 0,
      );
      expect(CommandBuilder.parseCommand(command), [
        '-i',
        inputPath,
        '-hide_banner',
        '-f',
        'mp3',
        outputPath,
      ]);
    },
  );

  test('existing history commands keep their legacy quoting behavior', () {
    expect(
      CommandBuilder.parseCommand(
        '-i "/media/my song.wav" -map \'0:a?\' "/output/my song.mp3"',
      ),
      ['-i', '/media/my song.wav', '-map', '0:a?', '/output/my song.mp3'],
    );
  });

  test('stored argument arrays reject non-string elements', () {
    expect(
      () => CommandBuilder.parseCommand('["-i",42]'),
      throwsFormatException,
    );
  });

  test('option ffmpeg_arg overrides the control flag and selection key', () {
    final args = build(
      controls: const [
        ConfigControl(
          type: .singleChoice,
          name: 'encoder',
          label: '',
          options: [
            ConfigControlOption(
              label: '',
              value: 'preferred',
              ffmpegArg: '-c:a libmp3lame',
            ),
          ],
          isVisible: false,
          shouldAddToArgs: true,
          ffmpegFlag: '-wrong-flag',
          defaultValue: 'preferred',
        ),
      ],
    );
    expect(args, containsAllInOrder(['-c:a', 'libmp3lame']));
    expect(args, isNot(contains('-wrong-flag')));
    expect(args, isNot(contains('preferred')));
  });

  test('unknown saved values cannot become executable arguments', () {
    final args = build(
      controls: const [
        ConfigControl(
          type: .singleChoice,
          name: 'encoder',
          label: '',
          options: [ConfigControlOption(label: '', value: '-c:a libmp3lame')],
          isVisible: false,
          shouldAddToArgs: true,
        ),
      ],
      selectedValues: const {'encoder': '-c:a unsupported'},
    );
    expect(args, isNot(contains('unsupported')));
    expect(args, isNot(contains('-c:a')));
  });

  test(
    'multi-choice arguments follow configuration order and preserve mappings',
    () {
      final args = build(
        controls: const [
          ConfigControl(
            type: .multiChoice,
            name: 'mapping',
            label: '',
            options: [
              ConfigControlOption(
                label: '',
                value: 'audio',
                ffmpegArg: '-map \'0:a?\'',
              ),
              ConfigControlOption(
                label: '',
                value: 'metadata',
                ffmpegArg: '-map_metadata 0:g',
              ),
            ],
            isVisible: false,
            shouldAddToArgs: true,
          ),
        ],
        selectedValues: {
          'mapping': jsonEncode(['metadata', 'audio']),
        },
      );
      expect(
        args,
        containsAllInOrder(['-map', '0:a?', '-map_metadata', '0:g']),
      );
    },
  );

  test('nested configuration keys are never emitted as FFmpeg arguments', () {
    final args = CommandBuilder.buildArgs(
      inputFilePath: '/input.wav',
      formatEntry: mp3,
      availableControls: const [
        ConfigControl(
          type: .singleChoice,
          name: 'profile',
          label: '',
          options: [ConfigControlOption(label: '', value: 'profile-settings')],
          isVisible: false,
          shouldAddToArgs: true,
          defaultValue: 'profile-settings',
        ),
      ],
      selectedValues: const {},
      outputFilePath: '/output.mp3',
      threadCount: 0,
      configurationKeys: {'profile-settings'},
    );
    expect(args, isNot(contains('profile-settings')));
  });

  test(
    'host FFmpeg converts files with both kinds of quotes in their names',
    () async {
      final temporaryDirectory = await Directory.systemTemp.createTemp(
        'mcu-command-test-',
      );
      addTearDown(() => temporaryDirectory.delete(recursive: true));
      const fileName = 'my "quoted" \'song\' \\ \$Việt';
      final inputPath = '${temporaryDirectory.path}/$fileName.wav';
      final outputPath = '${temporaryDirectory.path}/$fileName.mp3';
      final source = await Process.run('ffmpeg', [
        '-hide_banner',
        '-loglevel',
        'error',
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=440:duration=0.2',
        '-c:a',
        'pcm_s16le',
        inputPath,
      ]);
      expect(source.exitCode, 0, reason: '${source.stderr}');
      final command = CommandBuilder.buildCommand(
        inputFilePath: inputPath,
        formatEntry: mp3,
        availableControls: const [
          ConfigControl(
            type: .singleChoice,
            name: 'encoder',
            label: '',
            options: [ConfigControlOption(label: '', value: 'libmp3lame')],
            isVisible: false,
            shouldAddToArgs: true,
            ffmpegFlag: '-c:a',
            defaultValue: 'libmp3lame',
          ),
        ],
        selectedValues: const {},
        outputFilePath: outputPath,
        threadCount: 0,
      );
      final conversion = await Process.run(
        'ffmpeg',
        CommandBuilder.parseCommand(command),
      );
      expect(conversion.exitCode, 0, reason: '${conversion.stderr}');
      expect(await File(outputPath).length(), greaterThan(0));
      final probe = await Process.run('ffprobe', [
        '-v',
        'error',
        '-select_streams',
        'a:0',
        '-show_entries',
        'stream=codec_name',
        '-of',
        'json',
        outputPath,
      ]);
      expect(probe.exitCode, 0, reason: '${probe.stderr}');
      expect(
        (jsonDecode(probe.stdout as String) as Map)['streams'][0]['codec_name'],
        'mp3',
      );
    },
  );
}

List<String> build({
  required List<ConfigControl> controls,
  Map<String, String> selectedValues = const {},
}) {
  return CommandBuilder.buildArgs(
    inputFilePath: '/input.wav',
    formatEntry: mp3,
    availableControls: controls,
    selectedValues: selectedValues,
    outputFilePath: '/output.mp3',
    threadCount: 0,
  );
}
