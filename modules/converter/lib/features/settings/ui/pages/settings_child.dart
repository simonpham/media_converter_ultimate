import 'package:converter/converter.dart';
import 'package:flutter/material.dart';
import 'package:icons/icons.dart';
import 'package:platform_utils/platform_utils.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

part 'settings_child/app_theme.dart';
part 'settings_child/default_output_format.dart';
part 'settings_child/exclude_file_extensions.dart';
part 'settings_child/languages.dart';
part 'settings_child/thread_count.dart';

abstract class const SettingsChild({
  super.key,
}) extends StatelessWidget {
  SettingsPageItem get settings;

  Widget builder(BuildContext context);

  static void go(BuildContext context, SettingsPageItem settings) {
    final routeName = settings.routeName;
    if (routeName == null) {
      settings.handleOpen(context);
      return;
    }
    context.router.goNamed(routeName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          settings.getLabel(context),
        ),
      ),
      body: switch (settings.settingsKeys) {
        List<Enum> keys when keys.isNotEmpty => ValueListenableBuilder(
          valueListenable: keys.of(SettingsBox()),
          builder: (context, _, _) {
            return builder(context);
          },
        ),
        _ => builder(context),
      },
    );
  }
}
