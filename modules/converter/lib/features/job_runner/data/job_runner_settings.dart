import 'package:core/core.dart';

enum JobRunnerSettings {
  keepAppRunning,
  concurrentyLimit,
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

  int get concurrentyLimit => get(
    JobRunnerSettings.concurrentyLimit,
    defaultValue: 1,
  );

  set concurrentyLimit(int value) => put(
    JobRunnerSettings.concurrentyLimit,
    value,
  );
}
