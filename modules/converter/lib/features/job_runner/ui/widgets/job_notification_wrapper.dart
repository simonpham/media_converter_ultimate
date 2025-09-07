import 'package:converter/converter.dart';
import 'package:core/core.dart';
import 'package:design_system/utils/utils.dart';
import 'package:flutter/material.dart';

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

  @override
  Future<void> afterFirstLayout(BuildContext context) async {
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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    if (state == AppLifecycleState.paused) {
      // App is going to the background, start the service.
      await _jobNotificationService.start(
        JobNotificationServiceStartParams(
          notificationTitle: kAppName,
          notificationText: context.l10n.notificationChannelDescription,
        ),
      );
    } else if (state == AppLifecycleState.resumed) {
      // App is returning to the foreground, stop the service.
      await _jobNotificationService.stop();
    }
  }
}
