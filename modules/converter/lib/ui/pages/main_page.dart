import 'package:converter/converter.dart';
import 'package:core/core.dart';
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

class _MainPageState extends State<MainPage> {
  final JobManagerViewModel _jobManagerViewModel = JobManagerViewModel(
    FfmpegJobRunnerService(),
  );

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
