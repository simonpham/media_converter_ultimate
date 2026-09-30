import 'dart:convert';

import 'package:converter/features/job_maker/utils/configuration_selection.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inactive saved values cannot activate another codec branch', () {
    final groups = {
      'format': [
        choice('codec', ['a', 'b'], 'a'),
      ],
      'a': [
        choice('a-quality', ['20', '23'], '23'),
      ],
      'b': [
        choice('b-quality', ['26', '28'], '26'),
      ],
    };
    final controls = ConfigurationSelection.resolveControls(
      groups: groups,
      roots: ['format'],
      selectedValues: {'codec': 'a', 'inactive-preference': 'b'},
    );
    expect(controls.map((control) => control.name), ['codec', 'a-quality']);
  });

  test('nested groups resolve recursively at the parent position', () {
    final groups = {
      'format': [
        choice('codec', ['codec-settings'], 'codec-settings'),
        choice('tail', ['value'], 'value'),
      ],
      'codec-settings': [
        choice('profile', ['profile-settings'], 'profile-settings'),
      ],
      'profile-settings': [
        choice('bitrate', ['192k'], '192k'),
      ],
    };
    final controls = ConfigurationSelection.resolveControls(
      groups: groups,
      roots: ['format'],
      selectedValues: {},
    );
    expect(controls.map((control) => control.name), [
      'codec',
      'profile',
      'bitrate',
      'tail',
    ]);
  });

  test('cyclic and shared group references remain finite and appear once', () {
    final groups = {
      'format': [
        choice('codec', ['nested'], 'nested'),
        choice('second-reference', ['nested'], 'nested'),
      ],
      'nested': [
        choice('profile', ['format'], 'format'),
      ],
    };
    final controls = ConfigurationSelection.resolveControls(
      groups: groups,
      roots: ['format', 'nested'],
      selectedValues: {},
    );
    expect(controls.map((control) => control.name), [
      'codec',
      'profile',
      'second-reference',
    ]);
  });

  test(
    'saved options removed by a release fall back to valid active defaults',
    () {
      final groups = {
        'format': [
          choice('codec', ['a', 'b'], 'a'),
        ],
        'a': [
          choice('quality', ['20', '23'], '23'),
        ],
        'b': [
          choice('quality', ['26', '28'], '26'),
        ],
      };
      final values = ConfigurationSelection.normalizeValues(
        groups: groups,
        roots: ['format'],
        overrides: {
          'codec': 'removed-codec',
          'quality': 'removed-quality',
          'retired-control': 'unused',
        },
      );
      expect(values['codec'], 'a');
      expect(values['quality'], '23');
      expect(values.containsKey('retired-control'), isFalse);
    },
  );

  test(
    'switching branches repairs shared controls with different allowed values',
    () {
      final groups = {
        'format': [
          choice('codec', ['a', 'b'], 'a'),
        ],
        'a': [
          choice('sample-rate', ['44100', '48000'], '44100'),
        ],
        'b': [
          choice('sample-rate', ['8000', '16000'], '8000'),
        ],
      };
      final values = ConfigurationSelection.normalizeValues(
        groups: groups,
        roots: ['format'],
        overrides: {'codec': 'b', 'sample-rate': '44100'},
      );
      expect(values['sample-rate'], '8000');
    },
  );

  test(
    'multi-choice migration retains valid choices and repairs malformed data',
    () {
      final groups = {
        'format': [
          choice(
            'mapping',
            ['audio', 'metadata'],
            '["audio"]',
            type: .multiChoice,
          ),
        ],
      };
      Map<String, String> normalize(String mapping) =>
          ConfigurationSelection.normalizeValues(
            groups: groups,
            roots: ['format'],
            overrides: {'mapping': mapping},
          );
      expect(jsonDecode(normalize('["audio","retired","audio"]')['mapping']!), [
        'audio',
      ]);
      expect(jsonDecode(normalize('malformed-data')['mapping']!), ['audio']);
      expect(jsonDecode(normalize('metadata')['mapping']!), ['metadata']);
      expect(jsonDecode(normalize('[]')['mapping']!), isEmpty);
    },
  );

  test('multi-choice branches follow declared option order', () {
    final groups = {
      'format': [
        choice(
          'features',
          ['audio-settings', 'video-settings'],
          '[]',
          type: .multiChoice,
        ),
      ],
      'audio-settings': [
        choice('audio-rate', ['192k'], '192k'),
      ],
      'video-settings': [
        choice('video-rate', ['23'], '23'),
      ],
    };
    final controls = ConfigurationSelection.resolveControls(
      groups: groups,
      roots: ['format'],
      selectedValues: {'features': '["video-settings","audio-settings"]'},
    );
    expect(controls.map((control) => control.name), [
      'features',
      'audio-rate',
      'video-rate',
    ]);
  });
}

ConfigControl choice(
  String name,
  List<String> options,
  String defaultValue, {
  ConfigControlType type = .dropdown,
}) {
  return ConfigControl(
    type: type,
    name: name,
    label: '',
    options: [
      for (final value in options) ConfigControlOption(label: '', value: value),
    ],
    isVisible: true,
    shouldAddToArgs: true,
    defaultValue: defaultValue,
  );
}
