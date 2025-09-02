import 'package:converter/converter.dart';
import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

part 'settings_child/app_theme.dart';

abstract class SettingsChild extends StatelessWidget {
  SettingsPageItem get settings;

  List<Enum> get settingsBoxKeys;

  Widget builder(BuildContext context);

  static void go(BuildContext context, SettingsPageItem settings) {
    final routeName = settings.routeName;
    if (routeName == null) {
      return;
    }
    context.router.goNamed(routeName);
  }

  const SettingsChild({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          settings.getLabel(context),
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: settingsBoxKeys.of(SettingsBox()),
        builder: (context, _, _) {
          return builder(context);
        },
      ),
    );
  }
}
