import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:mcu/app.dart';

export 'app.dart';
export 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeConfigs().init();
  runApp(
    const MediaConverterUltimate(),
  );
}
