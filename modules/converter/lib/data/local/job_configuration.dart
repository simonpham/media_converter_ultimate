import 'dart:async';

import 'package:converter/converter.dart';

class JobConfigurationData extends EasyBox implements Disposable {
  @override
  String get boxKey => 'job_configurtion_data';

  factory JobConfigurationData() => injector<JobConfigurationData>();

  factory JobConfigurationData.create() => JobConfigurationData._();

  JobConfigurationData._();

  @override
  Future<void> onDispose() async {
    await box.close();
  }
}

extension JobConfigurationDataBoxExt on JobConfigurationData {
  Map<String, String> getLastKnownConfigurations(String formatName) {
    final Map<String, String> result = {};
    final rawData = get(formatName, defaultValue: <String, String>{});
    if (rawData is! Map) {
      return result;
    }
    for (final MapEntry(:key, :value) in rawData.entries) {
      if (key is! String || value is! String) {
        continue;
      }
      result[key] = value;
    }
    return result;
  }

  void setLastKnownConfigurations(
    String formatName,
    Map<String, String>? value,
  ) {
    put(formatName, value);
  }

  void clearConfigurations(String formatName) {
    put(formatName, null);
  }
}

extension FormatEntryExt on FormatEntry {
  Map<String, String> get lastKnownConfigurations {
    return JobConfigurationData().getLastKnownConfigurations(name);
  }

  void setLastKnownConfigurations(Map<String, String> value) {
    JobConfigurationData().setLastKnownConfigurations(name, value);
  }

  void clearConfigurations() {
    JobConfigurationData().clearConfigurations(name);
  }
}
