import 'package:flutter/widgets.dart';
import 'package:platform_utils/platform_utils.dart';

const String kDefaultLanguage = 'en';
const kSupportedLanguages = {
  'en': {
    'icon': 'assets/svg/flags/gb.svg',
    'title': 'English',
  },
  'zh': {
    'icon': 'assets/svg/flags/cn.svg',
    'title': '简体中文',
  },
  'zh_TW': {
    'icon': 'assets/svg/flags/tw.svg',
    'title': '繁體中文',
  },
  'de': {
    'icon': 'assets/svg/flags/de.svg',
    'title': 'Deutsch',
  },
  'id': {
    'icon': 'assets/svg/flags/id.svg',
    'title': 'Bahasa Indonesia',
  },
  'it': {
    'icon': 'assets/svg/flags/it.svg',
    'title': 'Italiano',
  },
  'es': {
    'icon': 'assets/svg/flags/es.svg',
    'title': 'Español',
  },
  'ja': {
    'icon': 'assets/svg/flags/ja.svg',
    'title': '日本語',
  },
  'tr': {
    'icon': 'assets/svg/flags/tr.svg',
    'title': 'Türkçe',
  },
  'pt': {
    'icon': 'assets/svg/flags/pt.svg',
    'title': 'Português',
  },
  'vi': {
    'icon': 'assets/svg/flags/vn.svg',
    'title': 'Tiếng Việt',
  },
  'ru': {
    'icon': 'assets/svg/flags/ru.svg',
    'title': 'Русский',
  },
};

Locale parseLocale(String language) {
  if (language.contains('_')) {
    final parts = language.split('_');
    return Locale(parts[0], parts.sublist(1).join('_'));
  }
  return Locale(language);
}

String get kDeviceLanguage {
  final localeName = Platform.localeName;
  if (localeName.startsWith('zh')) {
    final lower = localeName.toLowerCase();
    if (lower.contains('tw') ||
        lower.contains('hk') ||
        lower.contains('mo') ||
        lower.contains('hant')) {
      return 'zh_TW';
    }
    return 'zh';
  }
  if (localeName.contains('_')) {
    return localeName.split('_').firstOrNull ?? localeName;
  }
  return localeName;
}

const String kCommonVideoKey = 'common_video';
const String kCommonAudioKey = 'common_audio';
