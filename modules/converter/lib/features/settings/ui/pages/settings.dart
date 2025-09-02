import 'package:core/core.dart';
import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  static const String routeName = 'settings';
  static const String routePath = routeName;

  static void go(BuildContext context) async {
    context.router.goNamed(routeName);
  }

  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settingsTitle),
      ),
    );
  }
}
