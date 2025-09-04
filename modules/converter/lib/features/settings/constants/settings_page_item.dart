import 'package:converter/converter.dart';
import 'package:core/core.dart';
import 'package:design_system/assets.gen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

enum SettingsPageItem {
  defaultOutputFolder(
    settingsKeys: [
      JobMakerSettings.lastOutputDirectoryPath,
    ],
  ),
  defaultOutputFormat(
    routeName: 'default-output-format',
    settingsKeys: [
      JobMakerSettings.defaultOutputFormat,
    ],
  ),
  overwriteBehavior,
  appTheme(
    routeName: 'app-theme',
    settingsKeys: [
      CoreSettings.appTheme,
    ],
  ),
  showFileThumbnails,
  defaultSorting,
  clearCache,
  managePermissions,
  helpAndFaq,
  contactUs,
  legal,
  supportTheDeveloper;

  final String? routeName;
  final List<Enum>? settingsKeys;

  const SettingsPageItem({
    this.routeName,
    this.settingsKeys,
  });

  static List<SettingsPageItem> get availableOptions => kDebugMode
      ? values
      : [
          defaultOutputFolder,
          defaultOutputFormat,
          appTheme,
          legal,
          supportTheDeveloper,
        ];
}

extension SettingsPageItemExtensions on SettingsPageItem {
  GoRouterWidgetBuilder? get routerBuilder {
    return switch (this) {
      SettingsPageItem.defaultOutputFolder => null,
      SettingsPageItem.defaultOutputFormat =>
        (_, _) => const DefaultOutputFormatSettingsChild(),
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

  String? getDescription(BuildContext context) {
    return switch (this) {
      SettingsPageItem.defaultOutputFolder =>
        SettingsBox().lastOutputDirectoryPath,
      SettingsPageItem.defaultOutputFormat =>
        context.l10n.conversionDefaultOutputFormatDescription,
      SettingsPageItem.overwriteBehavior =>
        context.l10n.conversionOverwriteBehaviorDescription,
      SettingsPageItem.appTheme => context.l10n.displayAppThemeDescription,
      SettingsPageItem.showFileThumbnails =>
        context.l10n.displayShowFileThumbnailsDescription,
      SettingsPageItem.defaultSorting =>
        context.l10n.displayDefaultSortingDescription,
      SettingsPageItem.clearCache =>
        context.l10n.appManagementClearCacheDescription,
      SettingsPageItem.managePermissions =>
        context.l10n.appManagementManagePermissionsDescription,
      SettingsPageItem.helpAndFaq => null,
      SettingsPageItem.contactUs => null,
      SettingsPageItem.legal => context.l10n.aboutLegalDescription,
      SettingsPageItem.supportTheDeveloper =>
        context.l10n.monetizationSupportTheDeveloperDescription,
    };
  }

  String get appIcon {
    final icons = Assets.hugeicons.stroke;
    return switch (this) {
      SettingsPageItem.defaultOutputFolder => icons.filesFolders.folder01,
      SettingsPageItem.defaultOutputFormat => icons.filesFolders.fileExport,
      SettingsPageItem.overwriteBehavior => icons.addRemoveDelete.deleteThrow,
      SettingsPageItem.appTheme => icons.settings.customize,
      SettingsPageItem.showFileThumbnails => icons.imageCameraVideo.image01,
      SettingsPageItem.defaultSorting => icons.filterSorting.sorting01,
      SettingsPageItem.clearCache => icons.addRemoveDelete.delete04,
      SettingsPageItem.managePermissions => icons.security.securityLock,
      SettingsPageItem.helpAndFaq => icons.alertNotification.helpCircle,
      SettingsPageItem.contactUs => icons.communications.message01,
      SettingsPageItem.legal => icons.legal.legalDocument01,
      SettingsPageItem.supportTheDeveloper =>
        icons.businessAndFinance.dollarCircle,
    };
  }
}
