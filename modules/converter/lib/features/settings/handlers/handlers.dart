import 'dart:math';

import 'package:converter/converter.dart';
import 'package:flutter/widgets.dart';
import 'package:platform_utils/platform_utils.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

extension SettingsHandlers on SettingsPageItem {
  Future<void> handleOpen(BuildContext context) async {
    try {
      switch (this) {
        case SettingsPageItem.defaultOutputFolder:
          await _handleDefaultOutputFolder(context);
          break;
        case SettingsPageItem.defaultOutputFormat:
          // TODO: Handle this case.
          throw UnimplementedError();
        case SettingsPageItem.overwriteBehavior:
          // TODO: Handle this case.
          throw UnimplementedError();
        case SettingsPageItem.concurrencyLimit:
          await _handleConcurrencyLimit(context);
        case SettingsPageItem.threadCount:
          break;
        case SettingsPageItem.keepAppRunning:
          await _handleKeepAppRunningToggle(context);
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
          await _handleManagePermissions(context);
          break;
        case SettingsPageItem.changelog:
          await _handleViewChangelog(context);
          break;
        case SettingsPageItem.helpAndFaq:
          // TODO: Handle this case.
          throw UnimplementedError();
        case SettingsPageItem.contactUs:
          await _handleContactUs(context);
          break;
        case SettingsPageItem.legal:
          await _handleLegal(context);
          break;
        case SettingsPageItem.supportTheDeveloper:
          await _handleSupportTheDeveloper(context);
          break;
      }
    } catch (error, trace) {
      printError(error, trace);
      if (context.mounted) {
        context.toastFailure(
          error is Failure ? error : Failure(error.toString()),
        );
      }
    }
  }

  Future<void> _handleDefaultOutputFolder(BuildContext context) async {
    final currentPath = SettingsBox().lastOutputDirectoryPath;

    final path = await OutputDestinationPicker.show(
      context,
      initialPath: currentPath,
    );
    if (!context.mounted || path == null) return;

    await SettingsBox().put(JobMakerSettings.lastOutputDirectoryPath, path);
  }

  Future<void> _handleLegal(BuildContext context) async {
    final uri = Uri.parse(kPrivacyPolicyUrl);
    await launchUrl(uri);
  }

  Future<void> _handleSupportTheDeveloper(BuildContext context) async {
    final content = await ContentUtils.load(
      context,
      name: 'support_developer',
    );
    if (!context.mounted) return;
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

  Future<void> _handleContactUs(BuildContext context) async {
    await ContactUtils().sendEmail(
      context,
      subject: '[$kAppName] Support Request',
    );
  }

  Future<void> _handleViewChangelog(BuildContext context) async {
    return ChangelogUtils.showChangelogDialog(context);
  }

  Future<void> _handleKeepAppRunningToggle(BuildContext context) async {
    final settings = SettingsBox();
    if (settings.keepAppRunning) {
      await settings.put(JobRunnerSettings.keepAppRunning, false);
      return;
    }

    final service = injector<JobNotificationService>();
    final permissionGranted = await service.isNotificationPermissionGranted();
    if (!context.mounted) return;
    final action = permissionGranted
        ? ConfirmAction.positive
        : await ConfirmDialog.show(
            context,
            title: context.l10n.notificationPermission,
            message: context.l10n.notificationPermissionPrompt,
            negativeText: context.l10n.cancel,
            positiveText: context.l10n.enable,
          );
    if (!context.mounted || action != ConfirmAction.positive) return;

    await service.requestPermission();
    if (!context.mounted) return;
    final grantedAfterRequest = await service.isNotificationPermissionGranted();
    if (!context.mounted || !grantedAfterRequest) return;
    await service.init(
      JobNotificationServiceInitParams(
        channelName: kAppName,
        channelDescription: context.l10n.notificationChannelDescription,
      ),
    );
    if (!context.mounted) return;
    await settings.put(JobRunnerSettings.keepAppRunning, true);
  }

  Future<void> _handleConcurrencyLimit(BuildContext context) async {
    const minValue = 1.0;
    final maxValue = kMaxConcurrencyLimit.toDouble();
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

    await SettingsBox().put(JobRunnerSettings.concurrencyLimit, result.toInt());
  }

  Future<void> _handleManagePermissions(BuildContext context) async {
    final success = await openAppSettings();
    if (context.mounted && !success) {
      context.toastError(context.l10n.appManagementFailedToOpenSettings);
    }
  }
}
