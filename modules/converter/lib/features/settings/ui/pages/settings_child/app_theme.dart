part of '../settings_child.dart';

class AppThemeSettingsChild extends SettingsChild {
  @override
  SettingsPageItem get settings => SettingsPageItem.appTheme;

  @override
  List<Enum> get settingsBoxKeys => [CoreSettings.appTheme];

  @override
  Widget builder(BuildContext context) {
    return Column(children: []);
  }

  const AppThemeSettingsChild({
    super.key,
  });
}
