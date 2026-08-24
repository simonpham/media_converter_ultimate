import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FormatEntry', () {
    test('parses correctly from valid JSON', () {
      final json = {
        'name': 'mp4',
        'output_extension': 'mp4',
        'output_type': 'video',
        'should_add_to_args': true,
      };

      final entry = FormatEntry.fromJson(json);

      expect(entry.name, 'mp4');
      expect(entry.outputExtension, 'mp4');
      expect(entry.outputType, OutputType.video);
      expect(entry.shouldAddToArgs, isTrue);
    });

    test('parses audio format without should_add_to_args (defaulting to false)', () {
      final json = {
        'name': 'm4a',
        'output_extension': 'm4a',
        'output_type': 'audio',
        'should_add_to_args': false,
      };

      final entry = FormatEntry.fromJson(json);

      expect(entry.name, 'm4a');
      expect(entry.outputExtension, 'm4a');
      expect(entry.outputType, OutputType.audio);
      expect(entry.shouldAddToArgs, isFalse);
    });

    test('handles unknown output type gracefully', () {
      final json = {
        'name': 'custom',
        'output_extension': 'bin',
        'output_type': 'something_unknown',
      };

      final entry = FormatEntry.fromJson(json);
      expect(entry.outputType, OutputType.unknown);
    });
  });

  group('OutputType', () {
    test('parses known values', () {
      expect(OutputType.parse('audio'), OutputType.audio);
      expect(OutputType.parse('video'), OutputType.video);
      expect(OutputType.parse('invalid'), OutputType.unknown);
      expect(OutputType.parse(null), OutputType.unknown);
    });
  });
}
