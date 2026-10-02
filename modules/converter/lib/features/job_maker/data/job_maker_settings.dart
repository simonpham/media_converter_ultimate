import 'package:converter/converter.dart';

enum JobMakerSettings {
  defaultOutputFormat,
  lastOutputDirectoryPath,
  excludedFileExtensions,
  shouldExcludeNonMediaFiles,
}

extension JobMakerSettingsExt on SettingsBox {
  String? get defaultOutputFormat => readSetting<String?>(
    JobMakerSettings.defaultOutputFormat,
    defaultValue: null,
  );

  set defaultOutputFormat(String? value) => put(
    JobMakerSettings.defaultOutputFormat,
    value,
  );

  String? get lastOutputDirectoryPath => readSetting<String?>(
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
      return List.of(kDefaultExcludedFileExtensions);
    }

    return rawValue.whereType<String>().toList();
  }

  set excludedFileExtensions(List<String> value) => put(
    JobMakerSettings.excludedFileExtensions,
    value.toSet().toList(),
  );

  bool get shouldExcludeNonMediaFiles => readSetting(
    JobMakerSettings.shouldExcludeNonMediaFiles,
    defaultValue: true,
  );

  set shouldExcludeNonMediaFiles(bool value) => put(
    JobMakerSettings.shouldExcludeNonMediaFiles,
    value,
  );
}
