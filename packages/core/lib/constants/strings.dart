import 'package:platform_utils/platform_utils.dart';

const String kDefaultLanguage = 'en';

String get kDeviceLanguage {
  final localeName = Platform.localeName;
  if (localeName.contains('_')) {
    return localeName.split('_').firstOrNull ?? localeName;
  }
  return localeName;
}

const String kCommonVideoKey = 'common_video';
const String kCommonAudioKey = 'common_audio';
