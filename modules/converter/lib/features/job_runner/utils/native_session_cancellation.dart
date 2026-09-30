import 'dart:async';

import 'package:converter/features/job_runner/utils/mapper.dart';
import 'package:core/core.dart' show JobStatus;
import 'package:platform_utils/platform_utils.dart'
    show ReturnCode, SessionState;

/// A cancellation request can arrive before a native session starts. Keep
/// requesting it until native state confirms completion, including that race.
class NativeSessionCancellation {
  static Future<JobStatus> cancel({
    required Future<SessionState> Function() readState,
    required Future<ReturnCode?> Function() readReturnCode,
    required Future<void> Function() requestCancel,
    Duration timeout = const Duration(seconds: 10),
    Duration pollInterval = const Duration(milliseconds: 50),
  }) async {
    final elapsed = Stopwatch()..start();
    while (true) {
      final state = await readState();
      if (state == .completed || state == .failed) {
        return state.toJobStatus(returnCode: await readReturnCode());
      }
      if (elapsed.elapsed >= timeout) {
        throw TimeoutException(
          'Native cancellation was not acknowledged',
          timeout,
        );
      }
      await requestCancel();
      await Future<void>.delayed(pollInterval);
    }
  }
}
