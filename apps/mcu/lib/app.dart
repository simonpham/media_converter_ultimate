import 'package:design_system/design_system.dart';
import 'package:design_system/themes/configs.dart';
import 'package:flutter/material.dart';
import 'package:mcu/router.dart';

class MediaConverterUltimate extends StatelessWidget {
  const MediaConverterUltimate({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.theme.brightness == Brightness.dark;
    return MaterialApp.router(
      theme: ThemeConfigs().theme.getTheme(isDark: isDark),
      routerConfig: kAppRouter,
    );
  }
}
