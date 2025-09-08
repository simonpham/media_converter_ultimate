const String kAppDomain = 'sofluffy.io';
const String kAppWebsiteUrl = 'https://mcu.$kAppDomain';
const String kPrivacyPolicyUrl = '$kAppWebsiteUrl/privacy-policy';
const String kSupportEmail = 'support@$kAppDomain';
const String kAppPlayStoreUrl =
    'https://play.google.com/store/apps/details?id=com.github.khangnt.mcp';

const String kAppName = 'Media Converter Ultimate';

const String kSupportEmailSubject = '[MCU] Support request';

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

const List<String> kDefaultExcludedFileExtensions = [
  'pdf',
  'docx',
  'txt',
  'pptx',
  'csv',
  'xlsx',
  'zip',
  'rar',
  '7z',
  'exe',
  'msi',
  'dll',
  'sys',
  'tmp',
  'apk',
  'dat',
  'db',
];
