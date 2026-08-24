import 'package:converter/converter.dart';
import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:mcu/router.dart';

class const MediaConverterUltimate({
  super.key,
  required final AppTheme appTheme,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: [
        CoreSettings.language,
        CoreSettings.appTheme,
      ].of(SettingsBox()),
      builder: (context, _, _) {
        return MaterialApp.router(
          theme: appTheme.getTheme(isDark: false),
          darkTheme: appTheme.getTheme(isDark: true),
          themeMode: SettingsBox().appTheme,
          builder: (context, child) {
            return JobNotificationWrapper(
              child: child!,
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
