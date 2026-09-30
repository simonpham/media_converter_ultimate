import 'package:converter/converter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_utils/platform_utils.dart';

void main() {
  test('new and running sessions never start exporting', () {
    expect(SessionState.created.toJobStatus(), JobStatus.ready);
    expect(SessionState.running.toJobStatus(), JobStatus.running);
    expect(
      SessionState.running.toJobStatus(
        returnCode: ReturnCode(ReturnCode.success),
      ),
      JobStatus.running,
    );
  });

  test('only successful completed sessions can export their output', () {
    expect(
      SessionState.completed.toJobStatus(
        returnCode: ReturnCode(ReturnCode.success),
      ),
      JobStatus.cleaning,
    );
  });

  test('completed sessions with nonzero return codes are failures', () {
    for (final value in [1, 2, -1]) {
      expect(
        SessionState.completed.toJobStatus(returnCode: ReturnCode(value)),
        JobStatus.failed,
      );
    }
  });

  test('completed cancellation is not treated as successful conversion', () {
    expect(
      SessionState.completed.toJobStatus(
        returnCode: ReturnCode(ReturnCode.cancel),
      ),
      JobStatus.cancelled,
    );
  });

  test('a completed session without a result cannot export', () {
    expect(SessionState.completed.toJobStatus(), JobStatus.failed);
  });

  test('native exceptions remain failures regardless of return code', () {
    expect(SessionState.failed.toJobStatus(), JobStatus.failed);
    expect(
      SessionState.failed.toJobStatus(
        returnCode: ReturnCode(ReturnCode.success),
      ),
      JobStatus.failed,
    );
  });
}
