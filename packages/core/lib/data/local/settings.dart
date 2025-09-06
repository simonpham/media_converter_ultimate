import 'package:core/constants/constants.dart';
import 'package:core/core.dart'
    show injector, kDeviceLanguage, kSupportedLanguages;
import 'package:easy_hive/easy_hive.dart';
import 'package:flutter/material.dart';

enum CoreSettings {
  language,
  appTheme,
}

class SettingsBox extends EasyBox {
  @override
  String get boxKey => 'settings';

  factory SettingsBox() => injector<SettingsBox>();

  factory SettingsBox.create() => SettingsBox._();

  SettingsBox._();
}

extension LocalSettingsExt on SettingsBox {
  String get language {
    final String savedLanguage = get(
      CoreSettings.language,
      defaultValue: kDeviceLanguage,
    );
    if (!kSupportedLanguages.keys.contains(savedLanguage)) {
      return kDefaultLanguage;
    }
    return savedLanguage;
  }

  set language(String value) => put(CoreSettings.language, value);

  ThemeMode get appTheme {
    final rawData = get(
      CoreSettings.appTheme,
      defaultValue: ThemeMode.system.name,
    );
    return ThemeMode.values.firstWhere(
      (e) => e.name == '$rawData',
      orElse: () => ThemeMode.system,
    );
  }

  set appTheme(ThemeMode value) => put(CoreSettings.appTheme, value.name);
}
