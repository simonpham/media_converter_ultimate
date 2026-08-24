import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConfigControl', () {
    test('parses dropdown control with options and flag', () {
      final json = {
        'type': 'dropdown',
        'name': 'configs.mp4.crf.x264',
        'label': 'configs.common.crf.label',
        'should_add_to_args': true,
        'ffmpeg_flag': '-crf',
        'default': '23',
        'options': [
          {'label': 'configs.common.crf.18', 'value': '18'},
          {'label': 'configs.common.crf.23', 'value': '23'},
        ],
      };

      final control = ConfigControl.fromJson(json);

      expect(control.type, ConfigControlType.dropdown);
      expect(control.name, 'configs.mp4.crf.x264');
      expect(control.label, 'configs.common.crf.label');
      expect(control.shouldAddToArgs, isTrue);
      expect(control.ffmpegFlag, '-crf');
      expect(control.defaultValue, '23');
      expect(control.isVisible, isTrue);
      expect(control.options.length, 2);
      expect(control.options.first.label, 'configs.common.crf.18');
      expect(control.options.first.value, '18');
    });

    test('parses multi_choice control with ffmpeg_arg options', () {
      final json = {
        'type': 'multi_choice',
        'name': 'configs.flv.mapping',
        'label': 'configs.common.recommended_args.label',
        'is_visible': false,
        'should_add_to_args': true,
        'default': '["-map 0:v:0", "-map 0:a:0"]',
        'options': [
          {
            'label': 'configs.common.recommended_args.map_video',
            'ffmpeg_arg': '-map 0:v:0',
          },
          {
            'label': 'configs.common.recommended_args.map_audio',
            'ffmpeg_arg': '-map 0:a:0',
          },
        ],
      };

      final control = ConfigControl.fromJson(json);

      expect(control.type, ConfigControlType.multiChoice);
      expect(control.isVisible, isFalse);
      expect(control.shouldAddToArgs, isTrue);
      expect(control.options.length, 2);
      expect(control.options.first.ffmpegArg, '-map 0:v:0');
      expect(control.options.first.value, '-map 0:v:0');
    });

    test('handles single_choice with hidden visibility', () {
      final json = {
        'type': 'single_choice',
        'name': 'configs.opus.audio_encoder',
        'label': 'configs.common.audio_encoder',
        'is_visible': false,
        'should_add_to_args': true,
        'default': '-c:a libopus',
        'options': [
          {'label': '', 'value': '-c:a libopus'},
        ],
      };

      final control = ConfigControl.fromJson(json);

      expect(control.type, ConfigControlType.singleChoice);
      expect(control.isVisible, isFalse);
      expect(control.defaultValue, '-c:a libopus');
    });
  });

  group('ConfigControlType', () {
    test('parses all known control types', () {
      expect(
        ConfigControlType.fromValue('dropdown'),
        ConfigControlType.dropdown,
      );
      expect(
        ConfigControlType.fromValue('single_choice'),
        ConfigControlType.singleChoice,
      );
      expect(
        ConfigControlType.fromValue('multi_choice'),
        ConfigControlType.multiChoice,
      );
      expect(
        ConfigControlType.fromValue('radio_group'),
        ConfigControlType.radioGroup,
      );
      expect(ConfigControlType.fromValue('other'), ConfigControlType.unknown);
    });
  });
}
