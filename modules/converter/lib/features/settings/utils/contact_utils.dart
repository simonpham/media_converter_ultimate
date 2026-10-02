import 'package:converter/converter.dart';
import 'package:flutter/widgets.dart';
import 'package:platform_utils/platform_utils.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

class ContactUtils {
  Future<void> sendEmail(
    BuildContext context, {
    required String subject,
  }) async {
    final content = await ContentUtils.load(
      context,
      name: 'contact_us',
    );
    if (!context.mounted) return;
    final result = await ContentDialog.show(
      context,
      title: context.l10n.aboutContactUs,
      content: content ?? '',
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
