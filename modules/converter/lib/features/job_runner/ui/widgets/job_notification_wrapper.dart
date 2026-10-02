import 'dart:async';

import 'package:converter/converter.dart';
import 'package:core_storage_base/core_storage_base.dart';
import 'package:flutter/foundation.dart';
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

  late final JobNotificationCoordinator _coordinator;
  late final ValueListenable<void> _settingsListenable;
  JobNotificationServiceStartParams? _startParameters;
  AppLifecycleState _lifecycleState = .resumed;

  StreamSubscription<bool>? _isJobProcessingSubscription;

  bool _isJobProcessing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startParameters = .new(
      notificationTitle: kAppName,
      notificationText: context.l10n.notificationChannelDescription,
      iconBackgroundColor: context.theme.primaryColor,
    );
    _updateService();
  }

  @override
  Future<void> afterFirstLayout(BuildContext context) async {
    try {
      if (_isEnabled) {
        await _jobNotificationService.requestPermission();
        if (!mounted || !_isEnabled) return;
        await _jobNotificationService.init(
          JobNotificationServiceInitParams(
            channelName: kAppName,
            channelDescription: context.l10n.notificationChannelDescription,
          ),
        );
      }
      if (mounted) _updateService();
    } catch (error, trace) {
      printError(error, trace);
    }
  }

  @override
  void initState() {
    super.initState();
    _coordinator = injector<JobNotificationCoordinator>();
    _lifecycleState = WidgetsBinding.instance.lifecycleState ?? .resumed;
    _settingsListenable = [JobRunnerSettings.keepAppRunning].of(SettingsBox());
    _settingsListenable.addListener(_updateService);
    WidgetsBinding.instance.addObserver(this);
    _isJobProcessingSubscription = _jobStorage
        .watchIsJobPendingOrProcessing()
        .listen(
          (isProcessing) {
            _isJobProcessing = isProcessing;
            _updateService();
          },
          // A failed query cannot establish that processing has stopped.
          onError: printError,
        );
  }

  @override
  void dispose() {
    if (_isJobProcessingSubscription case final subscription?) {
      unawaited(subscription.cancel());
    }
    _settingsListenable.removeListener(_updateService);
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_coordinator.update(shouldRun: false));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    _updateService();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  void _updateService() {
    if (!mounted || _startParameters == null) return;
    final isBackground = switch (_lifecycleState) {
      .hidden || .paused || .detached => true,
      .resumed || .inactive => false,
    };
    unawaited(
      _coordinator.update(
        shouldRun: _isEnabled && _isJobProcessing && isBackground,
        parameters: _startParameters,
      ),
    );
  }
}
