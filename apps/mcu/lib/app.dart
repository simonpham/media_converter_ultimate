import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:mcu/router.dart';

class MediaConverterUltimate extends StatelessWidget {
  const MediaConverterUltimate({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.theme.brightness == Brightness.dark;
    return ValueListenableBuilder(
      valueListenable: [CoreSettings.language].of(
        SettingsBox(),
      ),
      builder: (context, _, _) {
        return MaterialApp.router(
          theme: ThemeConfigs().theme.getTheme(isDark: isDark),
          routerConfig: kAppRouter,
          locale: Locale(
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
