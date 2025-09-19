import 'package:converter/converter.dart' show ContentUtils;
import 'package:core/core.dart';
import 'package:design_system/design_system.dart' show ContentDialog;
import 'package:flutter/widgets.dart';
import 'package:platform_utils/platform_utils.dart';

class ChangelogUtils {
  static Future<void> check(BuildContext context) async {
    final packageInfo = await PackageInfo.fromPlatform();
    final String currentVersion = packageInfo.version;

    final String lastKnownVersion = SettingsBox().lastKnownVersion;
    if (lastKnownVersion == currentVersion) {
      return;
    }

    SettingsBox().lastKnownVersion = currentVersion;
    await showChangelogDialog(context);
  }

  static Future<void> showChangelogDialog(BuildContext context) async {
    final content = await ContentUtils.load(
      context,
      name: 'changelog',
    );
    await ContentDialog.show(
      context,
      title: context.l10n.changelog,
      content: content ?? '',
      neutralText: context.l10n.ok,
      useHtmlWidget: true,
    );
  }
}
