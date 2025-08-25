import 'package:converter/converter.dart';
import 'package:core/core.dart' show ConvertJob, EasyBox, injector;
import 'package:flutter/foundation.dart';

class LogData extends EasyBox {
  @override
  String get boxKey => 'log_data';

  factory LogData() => injector<LogData>();

  factory LogData.create() => LogData._();

  LogData._();
}

extension LogDataBoxExt on LogData {
  String getLog(String jobId) {
    return get(jobId, defaultValue: '');
  }

  void setLog(String jobId, String? value) {
    put(jobId, value);
  }

  void appendLog(String jobId, String value) {
    if (value.isEmpty) {
      return;
    }
    final currentLog = getLog(jobId);
    if (currentLog.isEmpty) {
      put(jobId, value);
      return;
    }
    put(jobId, '$currentLog\n$value');
  }

  ValueListenable<void> getLogListenable(String key) {
    return listenTo([key]);
  }

  void clearLog(String jobId) {
    put(jobId, null);
  }
}

extension LogDataExt on ConvertJob {
  String get logs {
    return LogData().getLog(id);
  }

  void clearLog() {
    LogData().clearLog(id);
  }
}
