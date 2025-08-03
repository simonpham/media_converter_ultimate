import 'package:core/core.dart';

enum JobMakerSettings {
  lastOutputDirectoryPath,
}

extension JobMakerSettingsExt on SettingsBox {
  String? get lastOutputDirectoryPath => get(
    JobMakerSettings.lastOutputDirectoryPath,
    defaultValue: null,
  );

  set lastOutputDirectoryPath(String? value) => put(
    JobMakerSettings.lastOutputDirectoryPath,
    value,
  );
}
