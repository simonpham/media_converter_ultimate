import 'dart:convert';

import 'package:converter/features/job_maker/utils/command_builder.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CommandBuilder', () {
    const testFormatEntryMp4 = FormatEntry(
      name: 'mp4',
      outputExtension: 'mp4',
      outputType: OutputType.video,
      shouldAddToArgs: true,
    );

    const testFormatEntryM4a = FormatEntry(
      name: 'm4a',
      outputExtension: 'm4a',
      outputType: OutputType.audio,
      shouldAddToArgs: false,
    );

    test('keeps encoder arguments that also trigger nested options', () {
      final controls = [
        const ConfigControl(
          type: ConfigControlType.singleChoice,
          name: 'configs.mp4.video_encoder',
          label: 'Encoder',
          options: [
            ConfigControlOption(label: 'x264', value: '-c:v libx264'),
          ],
          isVisible: true,
          shouldAddToArgs: true,
          defaultValue: '-c:v libx264',
        ),
        const ConfigControl(
          type: ConfigControlType.dropdown,
          name: 'configs.mp4.crf.x264',
          label: 'CRF',
          options: [
            ConfigControlOption(label: '23', value: '23'),
          ],
          isVisible: true,
          shouldAddToArgs: true,
          ffmpegFlag: '-crf',
          defaultValue: '23',
        ),
      ];

      final selectedValues = {
        'configs.mp4.video_encoder': '-c:v libx264',
        'configs.mp4.crf.x264': '23',
      };

      final args = CommandBuilder.buildArgs(
        inputFilePath: '/path/to/input.mov',
        formatEntry: testFormatEntryMp4,
        availableControls: controls,
        selectedValues: selectedValues,
        outputFilePath: '/path/to/output.mp4',
        threadCount: 0,
        configurationKeys: {'-c:v libx264'},
      );

      expect(args, contains('-i'));
      expect(args, contains('/path/to/input.mov'));
      expect(args, contains('-hide_banner'));
      expect(args, containsAllInOrder(['-c:v', 'libx264']));
      expect(args, contains('-crf'));
      expect(args, contains('23'));
      expect(args, containsAllInOrder(['-f', 'mp4']));
      expect(args, contains('/path/to/output.mp4'));

      final command = CommandBuilder.buildCommand(
        inputFilePath: '/path/to/input.mov',
        formatEntry: testFormatEntryMp4,
        availableControls: controls,
        selectedValues: selectedValues,
        outputFilePath: '/path/to/output.mp4',
        threadCount: 0,
        configurationKeys: {'-c:v libx264'},
      );

      expect(
        jsonDecode(command),
        [
          '-i',
          '/path/to/input.mov',
          '-hide_banner',
          '-c:v',
          'libx264',
          '-crf',
          '23',
          '-f',
          'mp4',
          '/path/to/output.mp4',
        ],
      );
    });

    test('omits -f when shouldAddToArgs is false (e.g. m4a, mkv)', () {
      final controls = [
        const ConfigControl(
          type: ConfigControlType.dropdown,
          name: 'configs.m4a.audio_bitrate',
          label: 'Bitrate',
          options: [
            ConfigControlOption(label: '192k', value: '192k'),
          ],
          isVisible: true,
          shouldAddToArgs: true,
          ffmpegFlag: '-b:a',
          defaultValue: '192k',
        ),
      ];

      final selectedValues = {
        'configs.m4a.audio_bitrate': '192k',
      };

      final args = CommandBuilder.buildArgs(
        inputFilePath: '/path/to/input.wav',
        formatEntry: testFormatEntryM4a,
        availableControls: controls,
        selectedValues: selectedValues,
        outputFilePath: '/path/to/output.m4a',
        threadCount: 4,
      );

      expect(args.contains('-f'), isFalse);
      expect(args, containsAllInOrder(['-threads', '4']));
      expect(args, contains('-b:a'));
      expect(args, contains('192k'));
    });

    test('parses multi-argument JSON arrays (e.g. stream mapping, compound scaling)', () {
      final controls = [
        const ConfigControl(
          type: ConfigControlType.multiChoice,
          name: 'configs.flv.mapping',
          label: 'Mapping',
          options: [
            ConfigControlOption(label: 'Video', value: '-map 0:v:0'),
            ConfigControlOption(label: 'Audio', value: '-map 0:a:0'),
          ],
          isVisible: false,
          shouldAddToArgs: true,
          defaultValue: '["-map 0:v:0", "-map 0:a:0"]',
        ),
      ];

      final selectedValues = {
        'configs.flv.mapping': '["-map 0:v:0", "-map 0:a:0"]',
      };

      final args = CommandBuilder.buildArgs(
        inputFilePath: '/path/to/in.mp4',
        formatEntry: testFormatEntryMp4,
        availableControls: controls,
        selectedValues: selectedValues,
        outputFilePath: '/path/to/out.flv',
        threadCount: 0,
      );

      expect(args, containsAllInOrder(['-map', '0:v:0']));
      expect(args, containsAllInOrder(['-map', '0:a:0']));
    });

    test('calculates correct output file path and name', () {
      final name = CommandBuilder.getOutputFileName(
        inputFilePath: '/media/videos/my_clip.mov',
        formatEntry: testFormatEntryMp4,
      );
      expect(name, 'my_clip.mp4');

      final customName = CommandBuilder.getOutputFileName(
        inputFilePath: '/media/videos/my_clip.mov',
        formatEntry: testFormatEntryMp4,
        overrideFileName: 'custom_name.mp4',
      );
      expect(customName, 'custom_name.mp4');

      final path = CommandBuilder.getOutputFilePath(
        inputFilePath: '/media/videos/my_clip.mov',
        formatEntry: testFormatEntryMp4,
        outputDirectoryPath: '/media/output',
      );
      expect(path, '/media/output/my_clip.mp4');
    });

    test('preserves album art and metadata args for audio conversions', () {
      const testFormatEntryMp3 = FormatEntry(
        name: 'mp3',
        outputExtension: 'mp3',
        outputType: OutputType.audio,
        shouldAddToArgs: true,
      );

      final controls = [
        const ConfigControl(
          type: ConfigControlType.dropdown,
          name: 'configs.mp3.audio_encoder',
          label: 'Encoder',
          options: [
            ConfigControlOption(label: 'LAME', value: 'libmp3lame'),
          ],
          isVisible: true,
          shouldAddToArgs: true,
          ffmpegFlag: '-c:a',
          defaultValue: 'libmp3lame',
        ),
        const ConfigControl(
          type: ConfigControlType.multiChoice,
          name: 'configs.mp3.album_art',
          label: 'Album Art',
          options: [
            ConfigControlOption(
              label: 'Preserve',
              value: '-map 0:v:disp:attached_pic?',
              ffmpegArg: '-map 0:v:disp:attached_pic?',
            ),
            ConfigControlOption(
              label: 'Copy Codec',
              value: '-c:v copy',
              ffmpegArg: '-c:v copy',
            ),
          ],
          isVisible: true,
          shouldAddToArgs: true,
          defaultValue: '["-map 0:v:disp:attached_pic?", "-c:v copy"]',
        ),
        const ConfigControl(
          type: ConfigControlType.multiChoice,
          name: 'configs.common.audio.recommended_args',
          label: 'Metadata',
          options: [
            ConfigControlOption(
              label: 'Metadata',
              value: '-map_metadata 0:g',
              ffmpegArg: '-map_metadata 0:g',
            ),
          ],
          isVisible: true,
          shouldAddToArgs: true,
          defaultValue: '["-map_metadata 0:g"]',
        ),
      ];

      final selectedValues = {
        'configs.mp3.audio_encoder': 'libmp3lame',
        'configs.mp3.album_art': '["-map 0:v:disp:attached_pic?", "-c:v copy"]',
        'configs.common.audio.recommended_args': '["-map_metadata 0:g"]',
      };

      final args = CommandBuilder.buildArgs(
        inputFilePath: '/path/to/song.flac',
        formatEntry: testFormatEntryMp3,
        availableControls: controls,
        selectedValues: selectedValues,
        outputFilePath: '/path/to/song.mp3',
        threadCount: 0,
      );

      expect(args, contains('-c:a'));
      expect(args, contains('libmp3lame'));
      expect(args, containsAllInOrder(['-map', '0:v:disp:attached_pic?']));
      expect(args, containsAllInOrder(['-c:v', 'copy']));
      expect(args, containsAllInOrder(['-map_metadata', '0:g']));
    });
  });
}
