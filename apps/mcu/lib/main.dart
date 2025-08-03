import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:mcu/app.dart';
import 'package:platform_utils/platform_utils.dart';

export 'app.dart';
export 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FileUtils.cleanConvertTemporaryDirectory();
  await ThemeConfigs().init();

  await Injector.init();

  await EasyBox.initialize(subDir: kAppDataDir);
  await SettingsBox().init();

  runApp(
    const MediaConverterUltimate(),
  );
}
