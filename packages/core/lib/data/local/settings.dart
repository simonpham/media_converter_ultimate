import 'package:core/constants/constants.dart';
import 'package:core/core.dart'
    show injector, kDeviceLanguage, kSupportedLanguages;
import 'package:easy_hive/easy_hive.dart';
import 'package:flutter/material.dart';

enum CoreSettings {
  language,
  appTheme,
  lastKnownVersion,
}

class SettingsBox extends EasyBox {
  @override
  String get boxKey => 'settings';

  factory SettingsBox() => injector<SettingsBox>();

  factory SettingsBox.create() => SettingsBox._();

  SettingsBox._();
}

extension LocalSettingsExt on SettingsBox {
  /// Invalid persisted values use a default without rewriting other preferences.
  T readSetting<T>(Object key, {required T defaultValue}) {
    final value = get(key, defaultValue: defaultValue);
    return value is T ? value : defaultValue;
  }

  String get lastKnownVersion {
    final savedVersion = readSetting(
      CoreSettings.lastKnownVersion,
      defaultValue: '',
    );
    return savedVersion;
  }

  set lastKnownVersion(String value) =>
      put(CoreSettings.lastKnownVersion, value);

  String get language {
    final savedLanguage = readSetting(
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
    final rawData = readSetting(
      CoreSettings.appTheme,
      defaultValue: ThemeMode.system.name,
    );
    return ThemeMode.values.firstWhere(
      (e) => e.name == rawData,
      orElse: () => ThemeMode.system,
    );
  }

  set appTheme(ThemeMode value) => put(CoreSettings.appTheme, value.name);
}
