import 'dart:async';

import 'package:core/core.dart';
import 'package:core_storage_base/core_storage_base.dart';
import 'package:core_storage_isar/core_storage_isar.dart';
import 'package:platform_utils/platform_utils.dart';
import 'package:utils/utils.dart';

class ConvertJobIsarStorage extends ConvertJobStorage {
  final Isar isar;

  // Don't use private constructor here as `analyzer` package
  // requires the 'primary-constructors' language feature to be enabled.
  const ConvertJobIsarStorage({
    required this.isar,
  });

  static Future<Isar> createIsarInstance() async {
    final dataFolder = await injector<FileService>().getAppDataDirectory();
    return await Isar.open(
      [IsarConvertJobSchema],
      directory: dataFolder.path,
    );
  }

  @override
  Future<Failure?> add(ConvertJob item) async {
    final convertedItem = item.toIsarModel();
    await isar.writeTxn(() async {
      return isar.isarConvertJobs.put(convertedItem);
    });
    return null;
  }

  @override
  FutureOr<Failure?> addAll(List<ConvertJob> items) async {
    final convertedItems = items.map((e) => e.toIsarModel()).toList();
    await isar.writeTxn(() async {
      return isar.isarConvertJobs.putAll(convertedItems);
    });
    return null;
  }

  @override
  Future<Failure?> delete(String id) async {
    final hashedId = fastHash(id);
    await isar.writeTxn(() {
      return isar.isarConvertJobs.delete(hashedId);
    });
    return null;
  }

  @override
  Future<ConvertJob?> get(String id) async {
    final hashedId = fastHash(id);
    final job = await isar.isarConvertJobs.get(hashedId);
    return job?.toOriginalModel();
  }

  @override
  Future<List<ConvertJob>> list(Pagination pagination) async {
    final (offset, limit) = switch (pagination) {
      OffsetLimitPagination p => (p.offset, p.limit),
      _ => (0, 0),
    };
    final jobs = await isar.isarConvertJobs
        .where()
        .sortByUpdatedAtDesc()
        .offset(offset)
        .limit(limit)
        .findAll();
    return jobs.map((job) => job.toOriginalModel()).toList();
  }

  @override
  Future<Failure?> update(ConvertJob item) async {
    final convertedItem = item
        .copyWith(updatedAt: Some(DateTime.now()))
        .toIsarModel();
    await isar.writeTxn(() {
      return isar.isarConvertJobs.put(convertedItem);
    });
    return null;
  }

  @override
  Future<int> count() async {
    final count = await isar.isarConvertJobs.count();
    return count;
  }

  @override
  Future<void> onDispose() async {
    if (isar.isOpen) await isar.close();
  }

  @override
  Stream<int> watchJobCount() {
    return isar.isarConvertJobs
        .watchLazy(fireImmediately: true)
        .asyncMap((_) => isar.isarConvertJobs.count());
  }

  @override
  Stream<List<ConvertJob>> watchCompletedJobs() {
    return isar.isarConvertJobs
        .where()
        .statusEqualTo(.completed)
        .or()
        .statusEqualTo(.failed)
        .or()
        .statusEqualTo(.cancelled)
        .sortByUpdatedAtDesc()
        .watch(fireImmediately: true)
        .map(
          (list) => list
              .whereType<IsarConvertJob>()
              .map((e) => e.toOriginalModel())
              .toList(),
        );
  }

  @override
  Stream<List<ConvertJob>> watchPendingJobs() {
    return isar.isarConvertJobs
        .where()
        .statusEqualTo(.pending)
        .sortByCreatedAt()
        .watch(fireImmediately: true)
        .map(
          (list) => list
              .whereType<IsarConvertJob>()
              .map((e) => e.toOriginalModel())
              .toList(),
        );
  }

  @override
  Stream<List<ConvertJob>> watchRunningJobs() {
    return isar.isarConvertJobs
        .where()
        .statusEqualTo(.running)
        .or()
        .statusEqualTo(.preparing)
        .or()
        .statusEqualTo(.ready)
        .or()
        .statusEqualTo(.cleaning)
        .or()
        .statusEqualTo(.stopping)
        .sortByUpdatedAtDesc()
        .watch(fireImmediately: true)
        .map(
          (list) => list
              .whereType<IsarConvertJob>()
              .map((e) => e.toOriginalModel())
              .toList(),
        );
  }

  @override
  Stream<List<ConvertJob>> watchActionRequiredJobs() {
    return isar.isarConvertJobs
        .where()
        .statusEqualTo(.actionRequired)
        .sortByUpdatedAtDesc()
        .watch(fireImmediately: true)
        .map(
          (list) => list
              .whereType<IsarConvertJob>()
              .map((e) => e.toOriginalModel())
              .toList(),
        );
  }

  @override
  Future<List<ConvertJob>> getAllPendingJobs() => _findPendingJobs();

  @override
  Future<List<ConvertJob>> getNextPendingJobs(int limit) {
    RangeError.checkNotNegative(limit, 'limit');
    return _findPendingJobs(limit: limit);
  }

  Future<List<ConvertJob>> _findPendingJobs({int? limit}) async {
    final query = isar.isarConvertJobs
        .where()
        .statusEqualTo(.pending)
        .sortByCreatedAt();
    final jobs = limit == null
        ? await query.findAll()
        : await query.limit(limit).findAll();
    return jobs.map((job) => job.toOriginalModel()).toList();
  }

  @override
  Future<List<ConvertJob>> getAllRunningJobs() async {
    return await isar.isarConvertJobs
        .where()
        .statusEqualTo(.running)
        .or()
        .statusEqualTo(.preparing)
        .or()
        .statusEqualTo(.ready)
        .or()
        .statusEqualTo(.cleaning)
        .or()
        .statusEqualTo(.stopping)
        .sortByUpdatedAtDesc()
        .findAll()
        .then(
          (list) => list
              .whereType<IsarConvertJob>()
              .map((e) => e.toOriginalModel())
              .toList(),
        );
  }

  @override
  Future<List<String>?> removeAllFinishedJobs() => _removeFinishedJobs();

  @override
  Future<List<String>?> removeOlderFinishedJobs(int dayCount) {
    RangeError.checkNotNegative(dayCount, 'dayCount');
    return _removeFinishedJobs(
      cutoff: DateTime.now().subtract(Duration(days: dayCount)),
    );
  }

  Future<List<String>?> _removeFinishedJobs({DateTime? cutoff}) async {
    try {
      return await isar.writeTxn(() async {
        final query = isar.isarConvertJobs
            .where()
            .statusEqualTo(.completed)
            .or()
            .statusEqualTo(.failed)
            .or()
            .statusEqualTo(.cancelled)
            .filter()
            .optional(
              cutoff != null,
              (query) => query.updatedAtLessThan(cutoff!),
            );
        // Capture only string IDs in the same transaction as deletion so log
        // cleanup cannot target a job that was kept or concurrently changed.
        final removedIds = await query.idProperty().findAll();
        await query.deleteAll();
        return removedIds;
      });
    } catch (err, trace) {
      printError(err, trace);
      return null;
    }
  }

  @override
  Future<List<ConvertJob>> fixInvalidJobs() async {
    try {
      final invalidIsarJobs = await isar.isarConvertJobs
          .where()
          .statusEqualTo(.pending)
          .or()
          .statusEqualTo(.running)
          .or()
          .statusEqualTo(.ready)
          .or()
          .statusEqualTo(.cleaning)
          .or()
          .statusEqualTo(.stopping)
          .or()
          .statusEqualTo(.preparing)
          .findAll();
      final fixedJobs = invalidIsarJobs
          .map(
            (e) => e.toOriginalModel().copyWith(
              status: Some(
                e.status == .stopping
                    ? .cancelled
                    : e.status == .cleaning && e.outputStaged
                    ? .actionRequired
                    : .pending,
              ),
              sessionId: const Some(null),
              progress: const Some(null),
              duration: const Some(null),
            ),
          )
          .toList();

      final fixedIsarJobs = fixedJobs.map((e) => e.toIsarModel()).toList();
      await isar.writeTxn(() async {
        await isar.isarConvertJobs.putAll(fixedIsarJobs);
      });

      return fixedJobs;
    } catch (err, trace) {
      printError(err, trace);
    }

    return [];
  }

  @override
  Stream<bool> watchIsJobPendingOrProcessing() {
    final query = isar.isarConvertJobs
        .where()
        .statusEqualTo(.pending)
        .or()
        .statusEqualTo(.running)
        .or()
        .statusEqualTo(.preparing)
        .or()
        .statusEqualTo(.ready)
        .or()
        .statusEqualTo(.cleaning)
        .or()
        .statusEqualTo(.stopping)
        .build();
    // Keep repeated true events: they allow the notification coordinator to
    // retry a transient native-service failure on the next progress update.
    return query
        .watchLazy(fireImmediately: true)
        .asyncMap((_) => query.isNotEmpty());
  }
}
