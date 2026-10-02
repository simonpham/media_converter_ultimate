import 'package:core/core.dart';

enum AdsSettings {
  appLaunchCount,
  filePickerAccessCount,
  outputFormatPickerAccessCount,
  successConversionCount,
}

extension AdsSettingsExt on SettingsBox {
  int _readCounter(AdsSettings key) {
    final value = readSetting(key, defaultValue: 0);
    return value < 0 ? 0 : value;
  }

  int get appLaunchCount => _readCounter(AdsSettings.appLaunchCount);

  set appLaunchCount(int value) => put(
    AdsSettings.appLaunchCount,
    value,
  );

  int get filePickerAccessCount =>
      _readCounter(AdsSettings.filePickerAccessCount);

  set filePickerAccessCount(int value) => put(
    AdsSettings.filePickerAccessCount,
    value,
  );

  int get outputFormatPickerAccessCount =>
      _readCounter(AdsSettings.outputFormatPickerAccessCount);

  set outputFormatPickerAccessCount(int value) => put(
    AdsSettings.outputFormatPickerAccessCount,
    value,
  );

  int get successConversionCount =>
      _readCounter(AdsSettings.successConversionCount);

  set successConversionCount(int value) => put(
    AdsSettings.successConversionCount,
    value,
  );
}
