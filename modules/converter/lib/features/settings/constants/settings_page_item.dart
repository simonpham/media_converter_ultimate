import 'package:converter/features/settings/ui/pages/settings_child.dart';
import 'package:core/core.dart';
import 'package:design_system/assets.gen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

enum SettingsPageItem {
  defaultOutputFolder,
  defaultOutputFormat,
  overwriteBehavior,
  appTheme(routeName: 'app-theme'),
  showFileThumbnails,
  defaultSorting,
  clearCache,
  managePermissions,
  helpAndFaq,
  contactUs,
  legal,
  supportTheDeveloper;

  final String? routeName;

  const SettingsPageItem({
    this.routeName,
  });

  static List<SettingsPageItem> get availableOptions => kDebugMode
      ? values
      : [
          appTheme,
        ];
}

extension SettingsPageItemExtensions on SettingsPageItem {
  GoRouterWidgetBuilder? get routerBuilder {
    return switch (this) {
      SettingsPageItem.defaultOutputFolder => null,
      SettingsPageItem.defaultOutputFormat => null,
      SettingsPageItem.overwriteBehavior => null,
      SettingsPageItem.appTheme => (_, _) => const AppThemeSettingsChild(),
      SettingsPageItem.showFileThumbnails => null,
      SettingsPageItem.defaultSorting => null,
      SettingsPageItem.clearCache => null,
      SettingsPageItem.managePermissions => null,
      SettingsPageItem.helpAndFaq => null,
      SettingsPageItem.contactUs => null,
      SettingsPageItem.legal => null,
      SettingsPageItem.supportTheDeveloper => null,
    };
  }

  String getLabel(BuildContext context) {
    return switch (this) {
      SettingsPageItem.defaultOutputFolder =>
        context.l10n.conversionDefaultOutputFolder,
      SettingsPageItem.defaultOutputFormat =>
        context.l10n.conversionDefaultOutputFormat,
      SettingsPageItem.overwriteBehavior =>
        context.l10n.conversionOverwriteBehavior,
      SettingsPageItem.appTheme => context.l10n.displayAppTheme,
      SettingsPageItem.showFileThumbnails =>
        context.l10n.displayShowFileThumbnails,
      SettingsPageItem.defaultSorting => context.l10n.displayDefaultSorting,
      SettingsPageItem.clearCache => context.l10n.appManagementClearCache,
      SettingsPageItem.managePermissions =>
        context.l10n.appManagementManagePermissions,
      SettingsPageItem.helpAndFaq => context.l10n.aboutHelpAndFaq,
      SettingsPageItem.contactUs => context.l10n.aboutContactUs,
      SettingsPageItem.legal => context.l10n.aboutLegal,
      SettingsPageItem.supportTheDeveloper =>
        context.l10n.monetizationSupportTheDeveloper,
    };
  }

  String get appIcon {
    return switch (this) {
      SettingsPageItem.defaultOutputFolder =>
        Assets.hugeicons.stroke.filesFolders.folder01,
      SettingsPageItem.defaultOutputFormat =>
        Assets.hugeicons.stroke.filesFolders.fileExport,
      SettingsPageItem.overwriteBehavior =>
        Assets.hugeicons.stroke.addRemoveDelete.deleteThrow,
      SettingsPageItem.appTheme => Assets.hugeicons.stroke.settings.customize,
      SettingsPageItem.showFileThumbnails =>
        Assets.hugeicons.stroke.imageCameraVideo.image01,
      SettingsPageItem.defaultSorting =>
        Assets.hugeicons.stroke.filterSorting.sorting01,
      SettingsPageItem.clearCache =>
        Assets.hugeicons.stroke.addRemoveDelete.delete04,
      SettingsPageItem.managePermissions =>
        Assets.hugeicons.stroke.security.securityLock,
      SettingsPageItem.helpAndFaq =>
        Assets.hugeicons.stroke.alertNotification.helpCircle,
      SettingsPageItem.contactUs =>
        Assets.hugeicons.stroke.communications.message01,
      SettingsPageItem.legal => Assets.hugeicons.stroke.legal.legalDocument01,
      SettingsPageItem.supportTheDeveloper =>
        Assets.hugeicons.stroke.businessAndFinance.dollarCircle,
    };
  }
}
