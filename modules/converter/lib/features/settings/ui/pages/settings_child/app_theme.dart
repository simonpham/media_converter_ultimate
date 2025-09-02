part of '../settings_child.dart';

class AppThemeSettingsChild extends SettingsChild {
  @override
  SettingsPageItem get settings => SettingsPageItem.appTheme;

  @override
  List<Enum> get settingsBoxKeys => [CoreSettings.appTheme];

  @override
  Widget builder(BuildContext context) {
    return Column(
      children: [
        for (final item in ThemeMode.values)
          RadioIconListTile(
            title: item.name,
            value: item,
            groupValue: SettingsBox().appTheme,
            onChanged: (value) {
              SettingsBox().appTheme = item;
            },
          ),
      ],
    );
  }

  const AppThemeSettingsChild({
    super.key,
  });
}
