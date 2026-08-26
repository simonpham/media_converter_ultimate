import 'dart:async';

import 'package:converter/converter.dart';
import 'package:core_storage_base/core_storage_base.dart';
import 'package:flutter/material.dart';
import 'package:sofluffy_ui/utils/utils.dart';

class JobNotificationWrapper extends StatefulWidget {
  final Widget child;

  const JobNotificationWrapper({
    super.key,
    required this.child,
  });

  @override
  State<JobNotificationWrapper> createState() => _JobNotificationWrapperState();
}

class _JobNotificationWrapperState extends State<JobNotificationWrapper>
    with WidgetsBindingObserver, AfterLayoutMixin {
  JobNotificationService get _jobNotificationService =>
      injector<JobNotificationService>();

  ConvertJobStorage get _jobStorage => ConvertJobStorage.getInstance();

  bool get _isEnabled => SettingsBox().keepAppRunning;

  StreamSubscription<bool>? _isJobProcessingSubscription;

  bool _isJobProcessing = false;

  @override
  Future<void> afterFirstLayout(BuildContext context) async {
    if (!_isEnabled) {
      return;
    }
    await _jobNotificationService.requestPermission();
    await _jobNotificationService.init(
      JobNotificationServiceInitParams(
        channelName: kAppName,
        channelDescription: context.l10n.notificationChannelDescription,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isJobProcessingSubscription = _jobStorage
        .watchIsJobPendingOrProcessing()
        .listen(
          (isProcessing) async {
            _isJobProcessing = isProcessing;
          },
        );
  }

  @override
  void dispose() {
    _isJobProcessingSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _jobNotificationService.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _handleAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  Future<void> _handleAppLifecycleState(AppLifecycleState state) async {
    if (!_isEnabled || !_isJobProcessing) {
      await _jobNotificationService.stop();
      return;
    }
    if (state == AppLifecycleState.paused && _isJobProcessing) {
      // App is going to the background, start the service.
      await _jobNotificationService.start(
        JobNotificationServiceStartParams(
          notificationTitle: kAppName,
          notificationText: context.l10n.notificationChannelDescription,
          iconBackgroundColor: context.theme.primaryColor,
        ),
      );
      return;
    }

    if (state == AppLifecycleState.resumed) {
      // App is returning to the foreground, stop the service.
      await _jobNotificationService.stop();
    }
  }
}
