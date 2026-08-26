import 'package:converter/converter.dart';
import 'package:flutter/material.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

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
