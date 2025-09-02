import 'package:core/core.dart';

enum AdsSettings {
  appLaunchCount,
  filePickerAccessCount,
  outputFormatPickerAccessCount,
  successConversionCount,
}

extension AdsSettingsExt on SettingsBox {
  int get appLaunchCount => get(
    AdsSettings.appLaunchCount,
    defaultValue: 0,
  );

  set appLaunchCount(int value) => put(
    AdsSettings.appLaunchCount,
    value,
  );

  int get filePickerAccessCount => get(
    AdsSettings.filePickerAccessCount,
    defaultValue: 0,
  );

  set filePickerAccessCount(int value) => put(
    AdsSettings.filePickerAccessCount,
    value,
  );

  int get outputFormatPickerAccessCount => get(
    AdsSettings.outputFormatPickerAccessCount,
    defaultValue: 0,
  );

  set outputFormatPickerAccessCount(int value) => put(
    AdsSettings.outputFormatPickerAccessCount,
    value,
  );

  int get successConversionCount => get(
    AdsSettings.successConversionCount,
    defaultValue: 0,
  );

  set successConversionCount(int value) => put(
    AdsSettings.successConversionCount,
    value,
  );
}
