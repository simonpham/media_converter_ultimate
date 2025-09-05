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
    const supportedLanguages = ['en', 'vi'];
    final language = supportedLanguages.contains(SettingsBox().language)
        ? SettingsBox().language
        : kDefaultLanguage;
    final content = await DefaultAssetBundle.of(context).loadString(
      'assets/html/support_developer_content/$language.html',
    );
    await ContentDialog.show(
      context,
      title: context.l10n.monetizationSupportTheDeveloper,
      content: content,
      neutralText: context.l10n.ok,
      useHtmlWidget: true,
    );
  }

  Future<void> _handleContactUs(BuildContext context) async {
    const supportedLanguages = ['en', 'vi'];
    final language = supportedLanguages.contains(SettingsBox().language)
        ? SettingsBox().language
        : kDefaultLanguage;
    final content = await DefaultAssetBundle.of(context).loadString(
      'assets/html/contact_us_content/$language.html',
    );
    final result = await ContentDialog.show(
      context,
      title: context.l10n.aboutContactUs,
      content: content,
      useHtmlWidget: true,
      negativeText: context.l10n.cancel,
      positiveText: context.l10n.ok,
    );
    if (result != ConfirmAction.positive) {
      return;
    }

    final deviceInfo = await DeviceInfoPlugin().deviceInfo;
    final packageInfo = await PackageInfo.fromPlatform();
    final deviceModel = switch (deviceInfo) {
      AndroidDeviceInfo deviceInfo => deviceInfo.model,
      IosDeviceInfo deviceInfo => deviceInfo.model,
      _ => '',
    };
    final osVersion = switch (deviceInfo) {
      AndroidDeviceInfo deviceInfo => deviceInfo.version.release,
      IosDeviceInfo deviceInfo => deviceInfo.systemVersion,
      _ => '',
    };
    final appVersion = packageInfo.version;

    const emailSubject = '[$kAppName] Support Request';
    final emailBody =
        '''
$kAppName version: $appVersion
Device model: $deviceModel
OS version: $osVersion

''';

    final Uri uri = Uri.parse(
      'mailto:$kSupportEmail?subject=$emailSubject&body=$emailBody',
    );
    await launchUrl(uri);
  }
}
