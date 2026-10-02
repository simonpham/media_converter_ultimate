import 'dart:async';

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
  @override
  void afterFirstLayout(BuildContext context) {
    unawaited(_checkStartup(context));
    unawaited(_checkChangelog(context));
  }

  Future<void> _checkStartup(BuildContext context) async {
    try {
      await context.read<JobManagerViewModel>().initialize();
    } catch (error, trace) {
      printError(error, trace);
      if (context.mounted) {
        context.toastFailure(
          error is Failure ? error : Failure(error.toString()),
        );
      }
    }
  }

  Future<void> _checkChangelog(BuildContext context) async {
    try {
      await ChangelogUtils.check(context);
    } catch (error, trace) {
      printError(error, trace);
    }
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: JobManager());
}
