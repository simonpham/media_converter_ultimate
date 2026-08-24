import 'package:flutter/foundation.dart';

@immutable
class const ConfigControl({
  required final ConfigControlType type,
  required final String name,
  required final String label,
  required final List<ConfigControlOption> options,
  required final bool isVisible,
  required final bool shouldAddToArgs,
  final String? ffmpegFlag,
  final String? defaultValue,
}) {
  factory ConfigControl.fromJson(dynamic json) {
    return .new(
      type: .fromValue(json['type']),
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

enum ConfigControlType(final String value) {
  radioGroup('radio_group'),
  dropdown('dropdown'),
  multiChoice('multi_choice'),
  singleChoice('single_choice'),
  unknown('');

  factory ConfigControlType.fromValue(dynamic value) {
    return ConfigControlType.values.firstWhere(
      (element) => element.value == '$value',
      orElse: () => .unknown,
    );
  }
}

@immutable
class const ConfigControlOption({
  required final String label,
  required final String value,
  final String? description,
  final String? ffmpegArg,
}) {
  factory ConfigControlOption.fromJson(dynamic json) {
    final ffmpegArg = json['ffmpeg_arg']?.toString();
    return .new(
      label: '${json['label'] ?? ''}',
      value: '${json['value'] ?? ffmpegArg ?? ''}',
      description: json['description']?.toString(),
      ffmpegArg: ffmpegArg,
    );
  }
}

