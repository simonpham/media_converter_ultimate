import 'package:converter/converter.dart' show SettingsPageItem;
import 'package:core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

enum SettingsCategory({
  required final List<SettingsPageItem> items,
}) {
  conversionAndOutput(
    items: [
      SettingsPageItem.defaultOutputFolder,
      SettingsPageItem.defaultOutputFormat,
      SettingsPageItem.threadCount,
      SettingsPageItem.concurrencyLimit,
      SettingsPageItem.overwriteBehavior,
      SettingsPageItem.keepAppRunning,
      SettingsPageItem.excludeFileExtensions,
    ],
  ),
  displayAndUi(
    items: [
      SettingsPageItem.languages,
      SettingsPageItem.appTheme,
      SettingsPageItem.showFileThumbnails,
      SettingsPageItem.defaultSorting,
    ],
  ),
  appManagement(
    items: [
      SettingsPageItem.clearCache,
      SettingsPageItem.managePermissions,
    ],
  ),
  aboutAndSupport(
    items: [
      SettingsPageItem.changelog,
      SettingsPageItem.helpAndFaq,
      SettingsPageItem.contactUs,
      SettingsPageItem.legal,
    ],
  ),
  monetization(
    items: [
      SettingsPageItem.supportTheDeveloper,
    ],
  );

  static List<SettingsCategory> get availableOptions => kDebugMode
      ? values
      : [
          conversionAndOutput,
          displayAndUi,
          aboutAndSupport,
          monetization,
        ];
}

extension SettingsCategoryExtensions on SettingsCategory {
  String getLabel(BuildContext context) {
    return switch (this) {
      .conversionAndOutput =>
        context.l10n.categoryConversionSettings,
      .displayAndUi => context.l10n.categoryDisplaySettings,
      .appManagement =>
        context.l10n.categoryAppManagementSettings,
      .aboutAndSupport =>
        context.l10n.categoryAboutAndSupportSettings,
      .monetization =>
        context.l10n.categoryMonetizationSettings,
    };
  }
}
