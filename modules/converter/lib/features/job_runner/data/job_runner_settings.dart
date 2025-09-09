import 'package:core/core.dart';

enum JobRunnerSettings {
  keepAppRunning,
}

extension JobRunnerSettingsExt on SettingsBox {
  bool get keepAppRunning => get(
    JobRunnerSettings.keepAppRunning,
    defaultValue: false,
  );

  set keepAppRunning(bool value) => put(
    JobRunnerSettings.keepAppRunning,
    value,
  );
}
