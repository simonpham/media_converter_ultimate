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
            title: item.getLabel(context),
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

extension on ThemeMode {
  String getLabel(BuildContext context) {
    return switch (this) {
      ThemeMode.system => context.l10n.appThemeSystem,
      ThemeMode.light => context.l10n.appThemeLight,
      ThemeMode.dark => context.l10n.appThemeDark,
    };
  }
}
