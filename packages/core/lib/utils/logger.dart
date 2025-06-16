import 'package:flutter/foundation.dart';

void printLog(dynamic log) {
  if (!kDebugMode) {
    return;
  }
  debugPrint('💬 $log');
}

void printError(dynamic err, StackTrace trace) {
  if (!kDebugMode) {
    return;
  }
  debugPrint('🐞 $err');
  debugPrint('$trace');
}
