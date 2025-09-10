import 'package:core/core.dart';
import 'package:core_storage_base/core_storage_base.dart';

abstract class ConvertJobStorage
    implements BaseStorage<ConvertJob>, Disposable {
  const ConvertJobStorage();

  static ConvertJobStorage getInstance() => injector<ConvertJobStorage>();

  Stream<int> watchJobCount();

  Stream<List<ConvertJob>> watchPendingJobs();

  Stream<List<ConvertJob>> watchRunningJobs();

  Stream<List<ConvertJob>> watchCompletedJobs();

  Stream<List<ConvertJob>> watchActionRequiredJobs();

  Future<bool> removeAllFinishedJobs();

  Future<bool> removeOlderFinishedJobs(int dayCount);

  Future<List<ConvertJob>> fixInvalidJobs();

  Stream<bool> watchIsJobPendingOrProcessing();
}
