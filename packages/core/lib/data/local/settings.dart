import 'package:core/core.dart' show injector, kDeviceLanguage;
import 'package:easy_hive/easy_hive.dart';

enum CoreSettings {
  language,
}

class SettingsBox extends EasyBox {
  @override
  String get boxKey => 'settings';

  factory SettingsBox() => injector<SettingsBox>();

  factory SettingsBox.create() => SettingsBox._();

  SettingsBox._();
}

extension LocalSettingsExt on SettingsBox {
  String get language =>
      get(CoreSettings.language, defaultValue: kDeviceLanguage);

  set language(String value) => put(CoreSettings.language, value);
}
