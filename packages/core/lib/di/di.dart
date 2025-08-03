import 'package:core/core.dart';

class Injector {
  static Future<void> init() async {
    injector.registerLazySingleton<SettingsBox>(
      () => SettingsBox.create(),
      dispose: (box) async => await box.close(),
    );
  }
}
