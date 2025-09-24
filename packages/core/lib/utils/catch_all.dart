import 'dart:async';

import 'package:core/core.dart' show printError;

FutureOr<void> catchAll(
  Function func,
) async {
  try {
    await func.call();
  } catch (err, trace) {
    printError(err, trace);
  }
}
