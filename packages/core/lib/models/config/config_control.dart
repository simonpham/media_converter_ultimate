import 'package:flutter/foundation.dart';

@immutable
class ConfigControl {
  final ConfigControlType type;
  final String name;
  final String label;
  final List<ConfigControlOption> options;
  final bool isVisible;
  final bool shouldAddToArgs;

  final String? ffmpegFlag;

  final String? defaultValue;

  const ConfigControl({
    required this.type,
    required this.name,
    required this.label,
    required this.options,
    required this.isVisible,
    required this.shouldAddToArgs,
    this.ffmpegFlag,
    this.defaultValue,
  });

  factory ConfigControl.fromJson(dynamic json) {
    return ConfigControl(
      type: ConfigControlType.fromValue(json['type']),
      name: '${json['name'] ?? ''}',
      label: '${json['label'] ?? ''}',
      options: json['options'] is List
          ? List<ConfigControlOption>.from(
              json['options']?.map((x) => ConfigControlOption.fromJson(x)) ??
                  <ConfigControlOption>[],
            )
          : <ConfigControlOption>[],
      isVisible: json['is_visible'] != false,
      shouldAddToArgs: json['should_add_to_args'] == true,
      ffmpegFlag: json['ffmpeg_flag']?.toString(),
      defaultValue: json['default']?.toString(),
    );
  }
}

enum ConfigControlType {
  radioGroup('radio_group'),
  dropdown('dropdown'),
  multiChoice('multi_choice'),
  singleChoice('single_choice'),
  unknown('');

  final String value;
  const ConfigControlType(this.value);

  factory ConfigControlType.fromValue(dynamic value) {
    return ConfigControlType.values.firstWhere(
      (element) => element.value == '$value',
      orElse: () => unknown,
    );
  }
}

@immutable
class ConfigControlOption {
  final String label;
  final String value;
  final String? description;

  final String? ffmpegArg;

  const ConfigControlOption({
    required this.label,
    required this.value,
    this.description,
    this.ffmpegArg,
  });

  factory ConfigControlOption.fromJson(dynamic json) {
    final ffmpegArg = json['ffmpeg_arg']?.toString();
    return ConfigControlOption(
      label: '${json['label'] ?? ''}',
      value: '${json['value'] ?? ffmpegArg ?? ''}',
      description: json['description']?.toString(),
      ffmpegArg: ffmpegArg,
    );
  }
}
