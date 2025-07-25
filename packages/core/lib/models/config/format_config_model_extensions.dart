part of 'format_config_model.dart';

extension FormatConfigModelHelperExtensions on FormatConfigModel {
  Future<Map<String, List<ConfigControl>>> loadConfigControls(
    FormatEntry format,
  ) async {
    final Map<String, List<ConfigControl>> configControls = {};
    final formatName = format.name;
    final config = formats.firstWhereOrNull((e) => e.name == formatName);
    if (config == null) {
      return configControls;
    }

    final configsToLoad = [kCommonKey, config.name];

    for (final configName in configsToLoad) {
      try {
        final configPath =
            'assets/configs/supported_configurations/$configName.json';
        final json = await rootBundle.loadString(configPath);
        final jsonMap = jsonDecode(json);
        for (final key in jsonMap.keys) {
          final controlsJson = jsonMap[key];
          if (controlsJson is! List) {
            continue;
          }
          final controls = List<ConfigControl>.from(
            controlsJson.map((x) => ConfigControl.fromJson(x)),
          );

          configControls[key] = controls;
        }
      } catch (err, trace) {
        printError(err, trace);
      }
    }

    return configControls;
  }

  LinearGradient getGradient(FormatEntry format) {
    final name = format.name;
    return uiGradients[name] ?? uiGradients['default']!;
  }
}
