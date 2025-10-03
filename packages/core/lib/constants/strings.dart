import 'package:platform_utils/platform_utils.dart';

const String kDefaultLanguage = 'en';
const kSupportedLanguages = {
  'en': {
    'icon': 'assets/svg/flags/gb.svg',
    'title': 'English',
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
};

String get kDeviceLanguage {
  final localeName = Platform.localeName;
  if (localeName.contains('_')) {
    return localeName.split('_').firstOrNull ?? localeName;
  }
  return localeName;
}

const String kCommonVideoKey = 'common_video';
const String kCommonAudioKey = 'common_audio';
