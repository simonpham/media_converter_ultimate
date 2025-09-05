import 'package:converter/converter.dart' show SettingsPageItem;
import 'package:core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

enum SettingsCategory {
  conversionAndOutput(
    items: [
      SettingsPageItem.defaultOutputFolder,
      SettingsPageItem.defaultOutputFormat,
      SettingsPageItem.overwriteBehavior,
    ],
  ),
  displayAndUi(
    items: [
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

  final List<SettingsPageItem> items;

  const SettingsCategory({
    required this.items,
  });

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
      SettingsCategory.conversionAndOutput =>
        context.l10n.categoryConversionSettings,
      SettingsCategory.displayAndUi => context.l10n.categoryDisplaySettings,
      SettingsCategory.appManagement =>
        context.l10n.categoryAppManagementSettings,
      SettingsCategory.aboutAndSupport =>
        context.l10n.categoryAboutAndSupportSettings,
      SettingsCategory.monetization =>
        context.l10n.categoryMonetizationSettings,
    };
  }
}
