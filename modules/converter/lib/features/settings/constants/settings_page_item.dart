import 'package:converter/converter.dart';
import 'package:core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:icons/icons.dart';

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
  concurrencyLimit(
    settingsKeys: [
      JobRunnerSettings.concurrencyLimit,
    ],
  ),
  keepAppRunning(
    settingsKeys: [
      JobRunnerSettings.keepAppRunning,
    ],
  ),
  excludeFileExtensions(
    routeName: 'exclude-file-extensions',
    settingsKeys: [
      JobMakerSettings.shouldExcludeNonMediaFiles,
      JobMakerSettings.excludedFileExtensions,
    ],
  ),
  languages(
    routeName: 'languages',
    settingsKeys: [
      CoreSettings.language,
    ],
  ),
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
  changelog,
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
          concurrencyLimit,
          keepAppRunning,
          excludeFileExtensions,
          languages,
          appTheme,
          managePermissions,
          changelog,
          contactUs,
          legal,
          supportTheDeveloper,
        ];
}

extension SettingsPageItemExtensions on SettingsPageItem {
  bool? get currentValue => switch (this) {
    SettingsPageItem.defaultOutputFolder => null,
    SettingsPageItem.defaultOutputFormat => null,
    SettingsPageItem.overwriteBehavior => null,
    SettingsPageItem.concurrencyLimit => null,
    SettingsPageItem.keepAppRunning => SettingsBox().keepAppRunning,
    SettingsPageItem.excludeFileExtensions => null,
    SettingsPageItem.languages => null,
    SettingsPageItem.appTheme => null,
    SettingsPageItem.showFileThumbnails => null,
    SettingsPageItem.defaultSorting => null,
    SettingsPageItem.clearCache => null,
    SettingsPageItem.managePermissions => null,
    SettingsPageItem.changelog => null,
    SettingsPageItem.helpAndFaq => null,
    SettingsPageItem.contactUs => null,
    SettingsPageItem.legal => null,
    SettingsPageItem.supportTheDeveloper => null,
  };

  GoRouterWidgetBuilder? get routerBuilder {
    return switch (this) {
      SettingsPageItem.defaultOutputFolder => null,
      SettingsPageItem.defaultOutputFormat =>
        (_, _) => const DefaultOutputFormatSettingsChild(),
      SettingsPageItem.overwriteBehavior => null,
      SettingsPageItem.concurrencyLimit => null,
      SettingsPageItem.keepAppRunning => null,
      SettingsPageItem.excludeFileExtensions =>
        (_, _) => const ExcludeFileExtensionsSettingsChild(),
      SettingsPageItem.languages => (_, _) => const LanguagesSettingsChild(),
      SettingsPageItem.appTheme => (_, _) => const AppThemeSettingsChild(),
      SettingsPageItem.showFileThumbnails => null,
      SettingsPageItem.defaultSorting => null,
      SettingsPageItem.clearCache => null,
      SettingsPageItem.managePermissions => null,
      SettingsPageItem.changelog => null,
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
      SettingsPageItem.concurrencyLimit => context.l10n.concurrencyLimit,
      SettingsPageItem.keepAppRunning => context.l10n.keepAppRunning,
      SettingsPageItem.excludeFileExtensions =>
        context.l10n.excludeFileExtensions,
      SettingsPageItem.languages => context.l10n.languages,
      SettingsPageItem.appTheme => context.l10n.displayAppTheme,
      SettingsPageItem.showFileThumbnails =>
        context.l10n.displayShowFileThumbnails,
      SettingsPageItem.defaultSorting => context.l10n.displayDefaultSorting,
      SettingsPageItem.clearCache => context.l10n.appManagementClearCache,
      SettingsPageItem.managePermissions =>
        context.l10n.appManagementManagePermissions,
      SettingsPageItem.helpAndFaq => context.l10n.aboutHelpAndFaq,
      SettingsPageItem.changelog => context.l10n.viewChangelog,
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
      SettingsPageItem.concurrencyLimit =>
        context.l10n.concurrencyLimitDescription(
          '${SettingsBox().concurrencyLimit}',
        ),
      SettingsPageItem.keepAppRunning => switch (SettingsBox().keepAppRunning) {
        true => context.l10n.keepAppRunningOnDescription,
        false => context.l10n.keepAppRunningOffDescription,
      },
      SettingsPageItem.excludeFileExtensions =>
        context.l10n.excludedFilesDescription,
      SettingsPageItem.languages => null,
      SettingsPageItem.appTheme => context.l10n.displayAppThemeDescription,
      SettingsPageItem.showFileThumbnails =>
        context.l10n.displayShowFileThumbnailsDescription,
      SettingsPageItem.defaultSorting =>
        context.l10n.displayDefaultSortingDescription,
      SettingsPageItem.clearCache =>
        context.l10n.appManagementClearCacheDescription,
      SettingsPageItem.managePermissions =>
        context.l10n.appManagementManagePermissionsDescription,
      SettingsPageItem.changelog => null,
      SettingsPageItem.helpAndFaq => null,
      SettingsPageItem.contactUs => null,
      SettingsPageItem.legal => context.l10n.aboutLegalDescription,
      SettingsPageItem.supportTheDeveloper =>
        context.l10n.monetizationSupportTheDeveloperDescription,
    };
  }

  String get appIcon {
    return switch (this) {
      SettingsPageItem.defaultOutputFolder => Assets.folder01,
      SettingsPageItem.defaultOutputFormat => Assets.fileExport,
      SettingsPageItem.overwriteBehavior => Assets.deleteThrow,
      SettingsPageItem.concurrencyLimit => Assets.layersLogoStrokeRounded,
      SettingsPageItem.keepAppRunning => Assets.flash,
      SettingsPageItem.excludeFileExtensions => Assets.fileBlock,
      SettingsPageItem.languages => Assets.globe,
      SettingsPageItem.appTheme => Assets.customize,
      SettingsPageItem.showFileThumbnails => Assets.image01,
      SettingsPageItem.defaultSorting => Assets.sorting01,
      SettingsPageItem.clearCache => Assets.delete04,
      SettingsPageItem.managePermissions => Assets.securityLock,
      SettingsPageItem.changelog => Assets.file02,
      SettingsPageItem.helpAndFaq => Assets.helpCircle,
      SettingsPageItem.contactUs => Assets.message01,
      SettingsPageItem.legal => Assets.legalDocument01,
      SettingsPageItem.supportTheDeveloper => Assets.dollarCircle,
    };
  }
}
