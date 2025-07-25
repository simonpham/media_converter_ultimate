import 'package:flutter/foundation.dart';

@immutable
class ConfigControl {
  final ConfigControlType type;
  final String name;
  final List<ConfigControlOption> options;

  final String? ffmpegFlag;

  const ConfigControl({
    required this.type,
    required this.name,
    required this.options,
    this.ffmpegFlag,
  });

  factory ConfigControl.fromJson(dynamic json) {
    return ConfigControl(
      type: ConfigControlType.fromValue(json['type']),
      name: '${json['name'] ?? ''}',
      options: json['options'] is List
          ? List<ConfigControlOption>.from(
              json['options']?.map((x) => ConfigControlOption.fromJson(x)) ??
                  <ConfigControlOption>[],
            )
          : <ConfigControlOption>[],
      ffmpegFlag: json['ffmpeg_flag']?.toString(),
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
