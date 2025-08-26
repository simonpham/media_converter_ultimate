import 'package:core/core.dart';
import 'package:core_storage_base/core_storage_base.dart';

abstract class ConvertJobStorage
    implements BaseStorage<ConvertJob>, Disposable {
  const ConvertJobStorage();

  static ConvertJobStorage get get => injector<ConvertJobStorage>();

  Stream<List<ConvertJob>> watchPendingJobs();

  Stream<List<ConvertJob>> watchRunningJobs();

  Stream<List<ConvertJob>> watchCompletedJobs();
}
