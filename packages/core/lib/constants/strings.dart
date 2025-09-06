import 'package:platform_utils/platform_utils.dart';

const String kDefaultLanguage = 'en';
const kSupportedLanguages = {
  'en': {
    'icon': 'assets/svg/flags/gb.svg',
    'title': 'English',
  },
  'vi': {
    'icon': 'assets/svg/flags/vn.svg',
    'title': 'Tiếng Việt',
  },
  'de': {
    'icon': 'assets/svg/flags/de.svg',
    'title': 'Deutsch',
  },
  'es': {
    'icon': 'assets/svg/flags/es.svg',
    'title': 'Español',
  },
  'id': {
    'icon': 'assets/svg/flags/id.svg',
    'title': 'Bahasa Indonesia',
  },
  'it': {
    'icon': 'assets/svg/flags/it.svg',
    'title': 'Italiano',
  },
  'ja': {
    'icon': 'assets/svg/flags/ja.svg',
    'title': '日本語',
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
