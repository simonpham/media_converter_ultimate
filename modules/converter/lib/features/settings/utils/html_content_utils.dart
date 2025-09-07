import 'package:core/core.dart';
import 'package:flutter/material.dart';

class HtmlContentUtils {
  static Future<String?> load(
    BuildContext context, {
    required String name,
  }) async {
    final language = SettingsBox().language;
    final content = await _load(context, name: name, language: language);
    if (content == null) {
      // Retry with default language.
      return _load(
        context,
        name: name,
        language: kDefaultLanguage,
      );
    }

    return content;
  }

  static Future<String?> _load(
    BuildContext context, {
    required String name,
    required String language,
  }) async {
    try {
      final content = await DefaultAssetBundle.of(context).loadString(
        'assets/html/$name/$language.html',
      );
      return content;
    } catch (err, trace) {
      printError(err, trace);
    }

    return null;
  }
}
