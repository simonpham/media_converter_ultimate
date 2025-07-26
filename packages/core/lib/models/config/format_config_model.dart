import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:utils/utils.dart';

part 'format_config_model_extensions.dart';

@immutable
class FormatConfigModel {
  final List<FormatEntry> formats;
  final Map<String, List<String>> supportedCodec;
  final Map<String, LinearGradient> uiGradients;

  static Future<FormatConfigModel?> get(BuildContext context) async {
    final json = await DefaultAssetBundle.of(context).loadString(
      'assets/configs/format.json',
    );
    return FormatConfigModel.fromJson(jsonDecode(json));
  }

  const FormatConfigModel({
    required this.formats,
    required this.supportedCodec,
    required this.uiGradients,
  });

  factory FormatConfigModel.fromJson(Map<String, dynamic> json) {
    final formatsList = requireField<List<dynamic>>(json, 'format');
    final formats = formatsList
        .map((e) => FormatEntry.fromJson(e as Map<String, dynamic>))
        .toList();

    final supportedCodec = parseMap<List<String>>(
      json,
      'supported_codec',
      (v) => (v as List).map((e) => e.toString()).toList(),
    );

    final rawGradients = requireField<Map<String, dynamic>>(
      json,
      'ui_gradients',
    );
    final uiGradients = <String, LinearGradient>{};
    rawGradients.forEach((key, value) {
      if (value is List && value.isNotEmpty) {
        final colors = value
            .map((e) => HexColorUtils.parse(e.toString()))
            .toList();
        uiGradients[key] = LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      }
    });

    return FormatConfigModel(
      formats: formats,
      supportedCodec: supportedCodec,
      uiGradients: uiGradients,
    );
  }
}

@immutable
class FormatEntry {
  final String name;
  final String outputExtension;
  final OutputType outputType;

  const FormatEntry({
    required this.name,
    required this.outputExtension,
    required this.outputType,
  });

  factory FormatEntry.fromJson(Map<String, dynamic> json) {
    final name = requireField<String>(json, 'name');
    final outputExtension = requireField<String>(json, 'output_extension');
    final outputType = OutputType.parse(json['output_type']);
    return FormatEntry(
      name: name,
      outputExtension: outputExtension,
      outputType: outputType,
    );
  }

  ConfigControl getEncoderPickerControl(List<String> supportedCodec) {
    final flag = outputType == OutputType.audio ? '-c:a' : '-c:v';
    return ConfigControl(
      type: ConfigControlType.dropdown,
      name: 'configs.common.encoder',
      shouldAddToArgs: true,
      options: supportedCodec
          .map(
            (codec) => ConfigControlOption(
              label: 'ui_codec_description.$codec',
              value: codec,
            ),
          )
          .toList(),
      ffmpegFlag: flag,
      defaultValue: supportedCodec.firstOrNull,
    );
  }
}

enum OutputType {
  audio('audio'),
  video('video'),
  unknown('');

  final String value;

  const OutputType(this.value);

  factory OutputType.parse(dynamic key) {
    return values.firstWhere(
      (e) => e.value == '$key',
      orElse: () => unknown,
    );
  }
}
