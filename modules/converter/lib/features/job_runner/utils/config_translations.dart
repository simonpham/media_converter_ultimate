import 'dart:convert';

import 'package:converter/converter.dart';
import 'package:flutter/material.dart';

extension ConfigTranslationsExtension on BuildContext {
  String configL10n(String key) {
    return read<JobMakerViewModel>().translations[key] ?? key;
  }
}

class ConfigTranslations {
  static Future<Map<String, String?>> get(
    BuildContext context, {
    String locale = kDefaultLanguage,
  }) async {
    final Map<String, String?> translations = {};

    try {
      final json = await DefaultAssetBundle.of(
        context,
      ).loadString('assets/configs/l10n/$locale.json');

      final Map<String, dynamic> jsonMap = jsonDecode(json);
      for (final String key in jsonMap.keys) {
        if (jsonMap[key] case String value) {
          translations[key] = value;
        }
      }
    } catch (err, trace) {
      printError(err, trace);
    }

    return translations;
  }
}
