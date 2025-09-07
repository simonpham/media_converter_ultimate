import 'package:converter/converter.dart';
import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:platform_utils/platform_utils.dart';

extension SettingsHandlers on SettingsPageItem {
  void handleOpen(BuildContext context) {
    switch (this) {
      case SettingsPageItem.defaultOutputFolder:
        _handleDefaultOutputFolder(context);
        break;
      case SettingsPageItem.defaultOutputFormat:
        // TODO: Handle this case.
        throw UnimplementedError();
      case SettingsPageItem.overwriteBehavior:
        // TODO: Handle this case.
        throw UnimplementedError();
      case SettingsPageItem.languages:
        // TODO: Handle this case.
        throw UnimplementedError();
      case SettingsPageItem.appTheme:
        // TODO: Handle this case.
        throw UnimplementedError();
      case SettingsPageItem.showFileThumbnails:
        // TODO: Handle this case.
        throw UnimplementedError();
      case SettingsPageItem.defaultSorting:
        // TODO: Handle this case.
        throw UnimplementedError();
      case SettingsPageItem.clearCache:
        // TODO: Handle this case.
        throw UnimplementedError();
      case SettingsPageItem.managePermissions:
        // TODO: Handle this case.
        throw UnimplementedError();
      case SettingsPageItem.helpAndFaq:
        // TODO: Handle this case.
        throw UnimplementedError();
      case SettingsPageItem.contactUs:
        _handleContactUs(context);
        break;
      case SettingsPageItem.legal:
        _handleLegal(context);
        break;
      case SettingsPageItem.supportTheDeveloper:
        _handleSupportTheDeveloper(context);
        break;
    }
  }

  Future<void> _handleDefaultOutputFolder(BuildContext context) async {
    final currentPath = SettingsBox().lastOutputDirectoryPath;

    final (path, failure) = await FileUtils.chooseSavePath(
      context,
      initialPath: currentPath,
    );

    if (failure != null) {
      context.toastFailure(failure);
    }

    if (path == null) {
      return;
    }

    SettingsBox().lastOutputDirectoryPath = path;
  }

  void _handleLegal(BuildContext context) {
    final uri = Uri.parse(kPrivacyPolicyUrl);
    launchUrl(uri);
  }

  Future<void> _handleSupportTheDeveloper(BuildContext context) async {
    final content = await ContentUtils.load(
      context, name: 'support_developer_content',
    );
    final result = await ContentDialog.show(
      context,
      title: context.l10n.monetizationSupportTheDeveloper,
      content: content ?? '',
      negativeText: context.l10n.goBack,
      positiveText: context.l10n.aboutRateTheApp,
      useHtmlWidget: true,
    );

    if (result != ConfirmAction.positive) {
      return;
    }

    final uri = Uri.parse(kAppPlayStoreUrl);
    await launchUrl(uri);
  }

  void _handleContactUs(BuildContext context) {
    ContactUtils().sendEmail(
      context,
      subject: '[$kAppName] Support Request',
    );
  }
}
