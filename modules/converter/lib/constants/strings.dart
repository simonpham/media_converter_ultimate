const String kAppDomain = 'sofluffy.io';
const String kAppWebsiteUrl = 'https://mcu.$kAppDomain';
const String kPrivacyPolicyUrl = '$kAppWebsiteUrl/privacy-policy';
const String kSupportEmail = 'support@$kAppDomain';

const String kAppName = 'Media Converter Ultimate';

const String kSupportEmailSubject = '[MCU] Support request';

const String kDefaultLocale = 'en';
const kSupportedLanguages = {
  'en': {
    'icon': 'assets/svg/flags/gb.svg',
    'title': 'English',
  },
  'vi': {
    'icon': 'assets/svg/flags/vn.svg',
    'title': 'Tiếng Việt',
  },
};

const String kDefaultOutputDirectoryName = 'MediaConverterPro';
const String kDefaultOutputDirectoryPath =
    '/Download/$kDefaultOutputDirectoryName';

const List<String> kStoragePaths = [
  '/sdcard',
  '/storage/emulated/0',
  '/storage/sdcard',
  '/mnt/sdcard',
  '/storage/sdcard0',
  '/storage/sdcard1',
  '/storage/extSdCard',
];
