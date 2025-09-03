import 'package:core/core.dart';

enum JobMakerSettings {
  defaultOutputFormat,
  lastOutputDirectoryPath,
}

extension JobMakerSettingsExt on SettingsBox {
  String? get defaultOutputFormat => get(
    JobMakerSettings.defaultOutputFormat,
    defaultValue: null,
  );

  set defaultOutputFormat(String? value) => put(
    JobMakerSettings.defaultOutputFormat,
    value,
  );

  String? get lastOutputDirectoryPath => get(
    JobMakerSettings.lastOutputDirectoryPath,
    defaultValue: null,
  );

  set lastOutputDirectoryPath(String? value) => put(
    JobMakerSettings.lastOutputDirectoryPath,
    value,
  );
}
