import 'package:converter/converter.dart';
import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:platform_utils/platform_utils.dart';

class ContactUtils {
  Future<void> sendEmail(
    BuildContext context, {
    required String subject,
  }) async {
    final supportedLanguages = [
      kDefaultLanguage,
      'de',
      'es',
      'id',
      'it',
      'ja',
      'vi',
    ];
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

    final emailBody =
        '''
$kAppName version: $appVersion
Device model: $deviceModel
OS version: $osVersion

''';

    final Uri uri = Uri.parse(
      'mailto:$kSupportEmail?subject=$subject&body=$emailBody',
    );
    await launchUrl(uri);
  }
}
