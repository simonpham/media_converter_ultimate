import 'package:converter/converter.dart';
import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

class const MainPage({
  super.key,
}) extends StatefulWidget {
  static const String routeName = 'main';
  static const String routePath = '/';

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with AfterLayoutMixin {
  final JobManagerViewModel _jobManagerViewModel = .new();

  @override
  void initState() {
    super.initState();
    SettingsBox().appLaunchCount++;
    printLog(
      '[AdsSettings] appLaunchCount increased: ${SettingsBox().appLaunchCount}',
    );
  }

  @override
  void afterFirstLayout(BuildContext context) {
    _jobManagerViewModel.restartPendingJobs();
    ChangelogUtils.check(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ChangeNotifierProvider<JobManagerViewModel>.value(
        value: _jobManagerViewModel,
        child: const JobManager(),
      ),
    );
  }
}
