import 'package:converter/features/job_runner/services/job_notification_service.dart';
import 'package:core/core.dart' show printError;

/// Serializes native service changes and applies the latest requested state.
class JobNotificationCoordinator(final JobNotificationService service) {
  Future<void> _tail = Future.value();
  bool _shouldRun = false;
  JobNotificationServiceStartParams? _parameters;

  Future<void> update({
    required bool shouldRun,
    JobNotificationServiceStartParams? parameters,
  }) {
    if (shouldRun && parameters == null) {
      throw ArgumentError.notNull('parameters');
    }
    _shouldRun = shouldRun;
    _parameters = parameters;
    _tail = _tail
        .then((_) async {
          final isRunning = await service.isServiceRunning();
          if (_shouldRun == isRunning) return;
          if (_shouldRun) {
            await service.start(_parameters!);
          } else {
            await service.stop();
          }
        })
        .catchError((Object error, StackTrace trace) {
          printError(error, trace);
        });
    return _tail;
  }
}
