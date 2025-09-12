import 'package:core/core.dart';

enum JobRunnerSettings {
  keepAppRunning,
  concurrencyLimit,
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

  int get concurrencyLimit => get(
    JobRunnerSettings.concurrencyLimit,
    defaultValue: 1,
  );

  set concurrencyLimit(int value) => put(
    JobRunnerSettings.concurrencyLimit,
    value,
  );
}
