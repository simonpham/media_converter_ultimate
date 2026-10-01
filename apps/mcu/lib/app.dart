import 'package:converter/converter.dart';
import 'package:flutter/material.dart';
import 'package:mcu/router.dart';
import 'package:mcu/theme_adapter.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

class MediaConverterUltimate extends StatelessWidget {
  final FluffyThemeData appTheme;

  const MediaConverterUltimate({
    super.key,
    required this.appTheme,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: [
        CoreSettings.language,
        CoreSettings.appTheme,
      ].of(SettingsBox()),
      builder: (context, _, _) {
        final themeMode = SettingsBox().appTheme;
        return MaterialApp.router(
          theme: appTheme.getTheme(isDark: false),
          darkTheme: appTheme.getTheme(isDark: true),
          themeMode: themeMode,
          builder: (context, child) {
            final isDark = switch (themeMode) {
              ThemeMode.dark => true,
              ThemeMode.light => false,
              ThemeMode.system =>
                MediaQuery.platformBrightnessOf(context) == Brightness.dark,
            };
            return FluffyTheme(
              data: appTheme.getFluffyTheme(isDark: isDark),
              child: JobNotificationWrapper(
                child: child!,
              ),
            );
          },
          routerConfig: kAppRouter,
          locale: parseLocale(
            SettingsBox().language,
          ),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        );
      },
    );
  }
}
