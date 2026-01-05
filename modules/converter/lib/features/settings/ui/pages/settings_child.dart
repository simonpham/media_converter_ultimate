import 'package:converter/converter.dart';
import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:icons/icons.dart';
import 'package:platform_utils/platform_utils.dart';

part 'settings_child/app_theme.dart';
part 'settings_child/default_output_format.dart';
part 'settings_child/exclude_file_extensions.dart';
part 'settings_child/thread_count.dart';
part 'settings_child/languages.dart';
part 'settings_child/file_service.dart';

abstract class SettingsChild extends StatelessWidget {
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
