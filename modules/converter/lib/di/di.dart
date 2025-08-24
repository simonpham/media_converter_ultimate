import 'package:converter/data/local/local.dart';
import 'package:core/core.dart';

class ConverterInjector {
  static Future<void> init() async {
    injector.registerLazySingleton<LogData>(
      () => LogData.create(),
      dispose: (box) async => await box.close(),
    );
  }
}
