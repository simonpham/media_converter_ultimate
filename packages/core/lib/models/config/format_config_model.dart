import 'dart:convert';

import 'package:core/core.dart';
import 'package:design_system/design_system.dart' show HexColorUtils;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:utils/utils.dart';

part 'format_config_model_extensions.dart';

@immutable
class const FormatConfigModel({
  required final List<FormatEntry> formats,
  required final Map<String, LinearGradient> uiGradients,
}) {
  static Future<FormatConfigModel?> get(BuildContext context) async {
    final json = await DefaultAssetBundle.of(context).loadString(
      'assets/configs/format.json',
    );
    return FormatConfigModel.fromJson(jsonDecode(json));
  }

  factory FormatConfigModel.fromJson(Map<String, dynamic> json) {
    final formatsList = requireField<List<dynamic>>(json, 'format');
    final formats = formatsList
        .map((e) => FormatEntry.fromJson(e as Map<String, dynamic>))
        .toList();

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
          begin: .topLeft,
          end: .bottomRight,
        );
      }
    });

    return .new(
      formats: formats,
      uiGradients: uiGradients,
    );
  }
}

@immutable
class const FormatEntry({
  required final String name,
  required final String outputExtension,
  required final OutputType outputType,
  required final bool shouldAddToArgs,
}) {
  factory FormatEntry.fromJson(Map<String, dynamic> json) {
    final name = requireField<String>(json, 'name');
    final outputExtension = requireField<String>(json, 'output_extension');
    final outputType = OutputType.parse(json['output_type']);
    final shouldAddToArgs = json['should_add_to_args'] == true;
    return .new(
      name: name,
      outputExtension: outputExtension,
      outputType: outputType,
      shouldAddToArgs: shouldAddToArgs,
    );
  }
}

enum OutputType(final String value) {
  audio('audio'),
  video('video'),
  unknown('');

  factory OutputType.parse(dynamic key) {
    return values.firstWhere(
      (e) => e.value == '$key',
      orElse: () => .unknown,
    );
  }
}

