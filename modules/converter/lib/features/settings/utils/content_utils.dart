import 'package:core/core.dart';
import 'package:flutter/material.dart';

class ContentUtils {
  static Future<String?> load(
    BuildContext context, {
    required String name,
    String extension = 'html',
  }) async {
    final language = SettingsBox().language;
    final bundle = DefaultAssetBundle.of(context);
    final content = await _load(
      bundle,
      name: name,
      language: language,
      extension: extension,
    );
    if (content == null) {
      // Retry with default language.
      return _load(
        bundle,
        name: name,
        language: kDefaultLanguage,
        extension: extension,
      );
    }

    return content;
  }

  static Future<String?> _load(
    AssetBundle bundle, {
    required String name,
    required String language,
    required String extension,
  }) async {
    try {
      final content = await bundle.loadString(
        'assets/content/$name/$language.$extension',
      );
      return content;
    } catch (err, trace) {
      printError(err, trace);
    }

    return null;
  }
}
