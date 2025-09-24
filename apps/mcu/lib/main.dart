import 'package:converter/converter.dart' show ConverterInjector;
import 'package:converter/data/data.dart';
import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:mcu/app.dart';
import 'package:platform_utils/platform_utils.dart';

export 'app.dart';
export 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  printLog('[main] Cleaning up temporary files...');
  await catchAll(FileUtils.cleanTemporaryDirectory);
  printLog('[main] Init new convert temporary folder...');
  await catchAll(
    () async => await FileUtils.getConvertTemporaryDirectory(null),
  );

  printLog('[main] Init ThemeConfigs...');
  await ThemeConfigs().init();

  printLog('[main] Init Injector...');
  await injector.reset();
  await Injector.init();
  await ConverterInjector.init();

  printLog('[main] Init Boxes...');
  await EasyBox.initialize(subDir: kDataFolderName);
  await SettingsBox().init();

  await LogData().init();
  await JobConfigurationData().init();

  printLog('[main] Init FlutterForegroundTask...');
  FlutterForegroundTask.initCommunicationPort();

  printLog('[main] Run app...');
  runApp(
    const MediaConverterUltimate(),
  );
}
