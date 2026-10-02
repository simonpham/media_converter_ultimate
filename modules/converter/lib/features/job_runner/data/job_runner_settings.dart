import 'package:core/core.dart';

const kMaxConcurrencyLimit = 4;
const kMaxThreadCount = 16;

enum JobRunnerSettings {
  keepAppRunning,
  concurrencyLimit,
  threadCount,
}

extension JobRunnerSettingsExt on SettingsBox {
  bool get keepAppRunning => readSetting(
    JobRunnerSettings.keepAppRunning,
    defaultValue: false,
  );

  set keepAppRunning(bool value) => put(
    JobRunnerSettings.keepAppRunning,
    value,
  );

  int get concurrencyLimit => readSetting(
    JobRunnerSettings.concurrencyLimit,
    defaultValue: 1,
  ).clamp(1, kMaxConcurrencyLimit).toInt();

  set concurrencyLimit(int value) => put(
    JobRunnerSettings.concurrencyLimit,
    value,
  );

  int get threadCount => readSetting(
    JobRunnerSettings.threadCount,
    defaultValue: 0,
  ).clamp(0, kMaxThreadCount).toInt();

  set threadCount(int value) => put(
    JobRunnerSettings.threadCount,
    value,
  );
}
