import 'package:converter/converter.dart';
import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

class MainPage extends StatefulWidget {
  static const String routeName = 'main';
  static const String routePath = '/';

  const MainPage({
    super.key,
  });

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with AfterLayoutMixin {
  final JobManagerViewModel _jobManagerViewModel = JobManagerViewModel();

  @override
  void afterFirstLayout(BuildContext context) {
    _jobManagerViewModel.restartPendingJobs();
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
