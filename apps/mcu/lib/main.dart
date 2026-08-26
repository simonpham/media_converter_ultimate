import 'package:converter/converter.dart' show ConverterInjector;
import 'package:converter/data/data.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:mcu/app.dart';
import 'package:platform_utils/platform_utils.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

export 'app.dart';
export 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  printLog('[main] Load AppTheme...');
  final appTheme = await ThemeLoader.loadDefault();

  printLog('[main] Init Injector...');
  await injector.reset();
  await Injector.init();
  await ConverterInjector.init();
  await ConverterInjector.runPostInit();

  printLog('[main] Init Boxes...');
  await EasyBox.initialize(subDir: kDataFolderName);
  await SettingsBox().init();

  await LogData().init();
  await JobConfigurationData().init();

  printLog('[main] Init FlutterForegroundTask...');
  FlutterForegroundTask.initCommunicationPort();

  printLog('[main] Run app...');
  runApp(
    MediaConverterUltimate(appTheme: appTheme),
  );
}
