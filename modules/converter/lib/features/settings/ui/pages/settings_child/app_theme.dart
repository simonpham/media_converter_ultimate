part of '../settings_child.dart';

class AppThemeSettingsChild extends SettingsChild {
  @override
  SettingsPageItem get settings => SettingsPageItem.appTheme;

  const AppThemeSettingsChild({
    super.key,
  });

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
