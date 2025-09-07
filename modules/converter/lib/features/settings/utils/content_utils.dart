import 'package:core/core.dart';
import 'package:flutter/material.dart';

class ContentUtils {
  static Future<String?> load(
    BuildContext context, {
    required String name,
    String extension = 'html',
  }) async {
    final language = SettingsBox().language;
    final content = await _load(
      context,
      name: name,
      language: language,
      extension: extension,
    );
    if (content == null) {
      // Retry with default language.
      return _load(
        context,
        name: name,
        language: kDefaultLanguage,
        extension: extension,
      );
    }

    return content;
  }

  static Future<String?> _load(
    BuildContext context, {
    required String name,
    required String language,
    required String extension,
  }) async {
    try {
      final content = await DefaultAssetBundle.of(context).loadString(
        'assets/content/$name/$language.$extension',
      );
      return content;
    } catch (err, trace) {
      printError(err, trace);
    }

    return null;
  }
}
