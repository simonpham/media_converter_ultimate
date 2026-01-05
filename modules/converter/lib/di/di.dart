import 'dart:async';

import 'package:converter/converter.dart';
import 'package:core/core.dart';
import 'package:core_storage_base/core_storage_base.dart';
import 'package:core_storage_isar/core_storage_isar.dart';
import 'package:mobile_ads/service/service.dart';
import 'package:mobile_ads_google/service/service.dart';
import 'package:platform_utils/platform_utils.dart';

class ConverterInjector {
  static Future<void> init() async {
    injector.registerLazySingleton<FileService>(
      () => ProxyFileService(
        safService: SafFileService(),
        directService: DirectFileService(),
        useSaf: () => SettingsBox().useSafFileService,
      ),
    );

    injector.registerLazySingleton<LogData>(
      () => LogData.create(),
    );

    injector.registerLazySingleton<JobConfigurationData>(
      () => JobConfigurationData.create(),
    );

    final isarInstance = await ConvertJobIsarStorage.createIsarInstance();
    injector.registerLazySingleton<ConvertJobStorage>(
      () => ConvertJobIsarStorage(isar: isarInstance),
    );

    injector.registerLazySingleton<JobRunnerService>(
      () => FfmpegJobRunnerService(),
    );

    injector.registerLazySingleton<JobNotificationService>(
      () => JobNotificationServiceImpl(),
    );

    final mobileAdsService = GoogleMobileAdsService();
    unawaited(mobileAdsService.initialize());
    injector.registerSingleton<MobileAdsService>(mobileAdsService);
  }

  static Future<void> runPostInit() async {
    printLog('[main] Cleaning up temporary files...');
    await catchAll(() => injector<FileService>().cleanTemporaryDirectory());

    printLog('[main] Init new convert temporary folder...');
    await catchAll(
      () async =>
          await injector<FileService>().getConvertTemporaryDirectory(null),
    );
  }
}
