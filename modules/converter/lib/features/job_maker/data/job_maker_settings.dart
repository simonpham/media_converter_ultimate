import 'package:converter/converter.dart';
import 'package:core/core.dart';

enum JobMakerSettings {
  defaultOutputFormat,
  lastOutputDirectoryPath,
  excludedFileExtensions,
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

  List<String> get excludedFileExtensions {
    final rawValue = get(
      JobMakerSettings.excludedFileExtensions,
      defaultValue: kDefaultExcludedFileExtensions,
    );

    if (rawValue is! List) {
      excludedFileExtensions = [];
      return [];
    }

    return List<String>.from(rawValue);
  }

  set excludedFileExtensions(List<String> value) => put(
    JobMakerSettings.excludedFileExtensions,
    value.toSet().toList(),
  );
}
