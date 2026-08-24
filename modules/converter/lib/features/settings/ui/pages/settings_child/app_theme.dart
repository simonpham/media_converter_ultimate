part of '../settings_child.dart';

class const AppThemeSettingsChild({
  super.key,
}) extends SettingsChild {
  @override
  SettingsPageItem get settings => .appTheme;

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
      .system => context.l10n.appThemeSystem,
      .light => context.l10n.appThemeLight,
      .dark => context.l10n.appThemeDark,
    };
  }
}
