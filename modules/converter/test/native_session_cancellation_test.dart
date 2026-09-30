import 'dart:async';

import 'package:converter/converter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_utils/platform_utils.dart'
    show ReturnCode, SessionState;

void main() {
  test(
    'retries a cancellation missed before the native session starts',
    () async {
      final states = <SessionState>[.created, .created, .running, .completed];
      final requests = <SessionState>[];
      var index = 0;
      final status = await NativeSessionCancellation.cancel(
        readState: () async => states[index++],
        readReturnCode: () async => ReturnCode(ReturnCode.cancel),
        requestCancel: () async => requests.add(states[index - 1]),
        pollInterval: Duration.zero,
      );
      expect(requests, <SessionState>[.created, .created, .running]);
      expect(status, JobStatus.cancelled);
    },
  );

  test('a completed conversion is not relabelled cancelled', () async {
    var requested = false;
    final status = await NativeSessionCancellation.cancel(
      readState: () async => SessionState.completed,
      readReturnCode: () async => ReturnCode(0),
      requestCancel: () async => requested = true,
    );
    expect(requested, isFalse);
    expect(status, JobStatus.cleaning);
  });

  test(
    'unacknowledged cancellation times out instead of freeing the slot',
    () async {
      await expectLater(
        NativeSessionCancellation.cancel(
          readState: () async => SessionState.running,
          readReturnCode: () async => null,
          requestCancel: () async {},
          timeout: const Duration(milliseconds: 5),
          pollInterval: const Duration(milliseconds: 1),
        ),
        throwsA(isA<TimeoutException>()),
      );
    },
  );

  test('a rejected native request cannot claim cancellation', () async {
    await expectLater(
      NativeSessionCancellation.cancel(
        readState: () async => SessionState.running,
        readReturnCode: () async => null,
        requestCancel: () async =>
            throw StateError('native rejected cancellation'),
      ),
      throwsStateError,
    );
  });
}
