import 'dart:async';

import 'package:converter/converter.dart';
import 'package:core/core.dart';
import 'package:core_storage_base/core_storage_base.dart';
import 'package:core_storage_isar/core_storage_isar.dart';
import 'package:mobile_ads/service/service.dart';
import 'package:mobile_ads_google/service/service.dart';

class ConverterInjector {
  static Future<void> init() async {
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

    final mobileAdsService = GoogleMobileAdsService();
    unawaited(mobileAdsService.initialize());
    injector.registerSingleton<MobileAdsService>(mobileAdsService);
  }
}
