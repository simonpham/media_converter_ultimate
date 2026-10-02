import 'package:converter/converter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:icons/icons.dart';

enum SettingsPageItem({
  final String? routeName,
  final List<Enum>? settingsKeys,
}) {
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
  threadCount(
    routeName: 'thread-count',
    settingsKeys: [
      JobRunnerSettings.threadCount,
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

  static List<SettingsPageItem> get availableOptions => kDebugMode
      ? values
      : [
          defaultOutputFolder,
          defaultOutputFormat,
          concurrencyLimit,
          threadCount,
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
    .defaultOutputFolder => null,
    .defaultOutputFormat => null,
    .overwriteBehavior => null,
    .concurrencyLimit => null,
    .threadCount => null,
    .keepAppRunning => SettingsBox().keepAppRunning,
    .excludeFileExtensions => null,
    .languages => null,
    .appTheme => null,
    .showFileThumbnails => null,
    .defaultSorting => null,
    .clearCache => null,
    .managePermissions => null,
    .changelog => null,
    .helpAndFaq => null,
    .contactUs => null,
    .legal => null,
    .supportTheDeveloper => null,
  };

  GoRouterWidgetBuilder? get routerBuilder {
    return switch (this) {
      .defaultOutputFolder => null,
      .defaultOutputFormat => (
        _,
        _,
      ) => const DefaultOutputFormatSettingsChild(),
      .overwriteBehavior => null,
      .concurrencyLimit => null,
      .threadCount => (_, _) => const ThreadCountSettingsChild(),
      .keepAppRunning => null,
      .excludeFileExtensions => (
        _,
        _,
      ) => const ExcludeFileExtensionsSettingsChild(),
      .languages => (_, _) => const LanguagesSettingsChild(),
      .appTheme => (_, _) => const AppThemeSettingsChild(),
      .showFileThumbnails => null,
      .defaultSorting => null,
      .clearCache => null,
      .managePermissions => null,
      .changelog => null,
      .helpAndFaq => null,
      .contactUs => null,
      .legal => null,
      .supportTheDeveloper => null,
    };
  }

  String getLabel(BuildContext context) {
    return switch (this) {
      .defaultOutputFolder => context.l10n.conversionDefaultOutputFolder,
      .defaultOutputFormat => context.l10n.conversionDefaultOutputFormat,
      .overwriteBehavior => context.l10n.conversionOverwriteBehavior,
      .concurrencyLimit => context.l10n.concurrencyLimit,
      .threadCount => context.l10n.threadCountTitle,
      .keepAppRunning => context.l10n.keepAppRunning,
      .excludeFileExtensions => context.l10n.excludeFileExtensions,
      .languages => context.l10n.languages,
      .appTheme => context.l10n.displayAppTheme,
      .showFileThumbnails => context.l10n.displayShowFileThumbnails,
      .defaultSorting => context.l10n.displayDefaultSorting,
      .clearCache => context.l10n.appManagementClearCache,
      .managePermissions => context.l10n.appManagementManagePermissions,
      .helpAndFaq => context.l10n.aboutHelpAndFaq,
      .changelog => context.l10n.viewChangelog,
      .contactUs => context.l10n.aboutContactUs,
      .legal => context.l10n.aboutLegal,
      .supportTheDeveloper => context.l10n.monetizationSupportTheDeveloper,
    };
  }

  String? getDescription(BuildContext context) {
    return switch (this) {
      .defaultOutputFolder => outputDestinationLabel(
        context,
        SettingsBox().lastOutputDirectoryPath,
      ),
      .defaultOutputFormat =>
        context.l10n.conversionDefaultOutputFormatDescription,
      .overwriteBehavior => context.l10n.conversionOverwriteBehaviorDescription,
      .concurrencyLimit => context.l10n.concurrencyLimitDescription(
        '${SettingsBox().concurrencyLimit}',
      ),
      .threadCount => context.l10n.threadCountSubtitle(
        ThreadCountSettingsChild.getValueLabel(
          context,
          SettingsBox().threadCount,
        ),
      ),
      .keepAppRunning => switch (SettingsBox().keepAppRunning) {
        true => context.l10n.keepAppRunningOnDescription,
        false => context.l10n.keepAppRunningOffDescription,
      },
      .excludeFileExtensions => context.l10n.excludedFilesDescription,
      .languages => null,
      .appTheme => context.l10n.displayAppThemeDescription,
      .showFileThumbnails => context.l10n.displayShowFileThumbnailsDescription,
      .defaultSorting => context.l10n.displayDefaultSortingDescription,
      .clearCache => context.l10n.appManagementClearCacheDescription,
      .managePermissions =>
        context.l10n.appManagementManagePermissionsDescription,
      .changelog => null,
      .helpAndFaq => null,
      .contactUs => null,
      .legal => context.l10n.aboutLegalDescription,
      .supportTheDeveloper =>
        context.l10n.monetizationSupportTheDeveloperDescription,
    };
  }

  String get appIcon {
    return switch (this) {
      .defaultOutputFolder => Assets.folder01,
      .defaultOutputFormat => Assets.fileExport,
      .overwriteBehavior => Assets.deleteThrow,
      .concurrencyLimit => Assets.layersLogoStrokeRounded,
      .threadCount => Assets.layers01StrokeRounded,
      .keepAppRunning => Assets.flash,
      .excludeFileExtensions => Assets.fileBlock,
      .languages => Assets.globe,
      .appTheme => Assets.customize,
      .showFileThumbnails => Assets.image01,
      .defaultSorting => Assets.sorting01,
      .clearCache => Assets.delete04,
      .managePermissions => Assets.securityLock,
      .changelog => Assets.file02,
      .helpAndFaq => Assets.helpCircle,
      .contactUs => Assets.message01,
      .legal => Assets.legalDocument01,
      .supportTheDeveloper => Assets.dollarCircle,
    };
  }
}
