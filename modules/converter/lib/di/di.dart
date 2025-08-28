import 'package:converter/data/local/local.dart';
import 'package:core/core.dart';
import 'package:core_storage_base/core_storage_base.dart';
import 'package:core_storage_isar/core_storage_isar.dart';

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
  }
}
