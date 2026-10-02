import 'dart:async';

import 'package:converter/converter.dart';
import 'package:flutter/foundation.dart';

class LogData extends EasyBox implements Disposable {
  @override
  String get boxKey => 'log_data';

  factory LogData() => injector<LogData>();

  factory LogData.create() => LogData._();

  LogData._();

  Future<void> clearLogs(Iterable<String> jobIds) => box.deleteAll(jobIds);

  @override
  Future<void> onDispose() async {
    await box.close();
  }
}

extension LogDataBoxExt on LogData {
  String getLog(String jobId) {
    return get(jobId, defaultValue: '');
  }

  void setLog(String jobId, String? value) {
    _observeWrite(() => put(jobId, value));
  }

  void appendLog(String jobId, String value) {
    if (value.isEmpty) {
      return;
    }
    _observeWrite(() {
      final currentLog = getLog(jobId);
      return put(jobId, currentLog.isEmpty ? value : '$currentLog\n$value');
    });
  }

  void _observeWrite(Future<void> Function() write) {
    unawaited(
      Future<void>.sync(write).catchError((Object error, StackTrace trace) {
        printError(error, trace);
      }),
    );
  }

  ValueListenable<void> getLogListenable(String key) {
    return listenTo([key]);
  }

  void clearLog(String jobId) {
    setLog(jobId, null);
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
