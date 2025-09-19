import 'dart:math';

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
      case SettingsPageItem.concurrencyLimit:
        _handleConcurrencyLimit(context);
      case SettingsPageItem.keepAppRunning:
        _handleKeepAppRunningToggle(context);
        break;
      case SettingsPageItem.excludeFileExtensions:
        break;
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
        _handleManagePermissions(context);
        break;
      case SettingsPageItem.changelog:
        _handleViewChangelog(context);
        break;
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
      context,
      name: 'support_developer',
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

  Future<void> _handleViewChangelog(BuildContext context) async {
    return ChangelogUtils.showChangelogDialog(context);
  }

  Future<void> _handleKeepAppRunningToggle(BuildContext context) async {
    final isEnable = SettingsBox().keepAppRunning;
    if (isEnable) {
      SettingsBox().keepAppRunning = false;
      return;
    }

    final service = injector<JobNotificationService>();

    final action = await service.isNotificationPermissionGranted()
        ? ConfirmAction.positive
        : await ConfirmDialog.show(
            context,
            title: context.l10n.notificationPermission,
            message: context.l10n.notificationPermissionPrompt,
            negativeText: context.l10n.cancel,
            positiveText: context.l10n.enable,
          );

    if (action != ConfirmAction.positive) {
      SettingsBox().keepAppRunning = false;
      return;
    }

    await service.requestPermission();
    if (!await service.isNotificationPermissionGranted()) {
      SettingsBox().keepAppRunning = false;
      return;
    }

    await service.init(
      JobNotificationServiceInitParams(
        channelName: kAppName,
        channelDescription: context.l10n.notificationChannelDescription,
      ),
    );
    SettingsBox().keepAppRunning = true;
  }

  Future<void> _handleConcurrencyLimit(BuildContext context) async {
    const minValue = 1.0;
    const maxValue = 4.0;
    final divisions = (maxValue - minValue).toInt();
    final currentValue = min(
      max(SettingsBox().concurrencyLimit, minValue),
      maxValue,
    );
    final result = await InputSliderDialog.show(
      context,
      title: context.l10n.concurrencyLimit,
      labelBuilder: (value) => value.toStringAsFixed(0),
      hintBuilder: (_) => context.l10n.concurrencyLimitHint,
      initialValue: currentValue.toDouble(),
      min: minValue,
      max: maxValue,
      divisions: divisions,
      cancelText: context.l10n.cancel,
      confirmText: context.l10n.ok,
    );

    if (result == null) {
      return;
    }

    SettingsBox().concurrencyLimit = result.toInt();
  }

  Future<void> _handleManagePermissions(BuildContext context) async {
    final success = await openAppSettings();
    if (!success) {
      context.toastError(context.l10n.appManagementFailedToOpenSettings);
    }
  }
}
