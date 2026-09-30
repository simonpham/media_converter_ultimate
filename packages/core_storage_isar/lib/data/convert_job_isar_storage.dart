import 'dart:async';

import 'package:core/core.dart';
import 'package:core_storage_base/core_storage_base.dart';
import 'package:core_storage_isar/core_storage_isar.dart';
import 'package:platform_utils/platform_utils.dart';
import 'package:utils/utils.dart';

class const ConvertJobIsarStorage({
  required final Isar isar,
}) extends ConvertJobStorage {
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
  void onDispose() {
    isar.close();
  }

  @override
  Stream<int> watchJobCount() {
    return isar.isarConvertJobs
        .where()
        .watch(fireImmediately: true)
        .map((list) => list.length);
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
  Future<List<ConvertJob>> getAllPendingJobs() async {
    return await isar.isarConvertJobs
        .where()
        .statusEqualTo(.pending)
        .sortByCreatedAt()
        .findAll()
        .then(
          (list) => list
              .whereType<IsarConvertJob>()
              .map((e) => e.toOriginalModel())
              .toList(),
        );
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
  Future<bool> removeAllFinishedJobs() async {
    try {
      await isar.writeTxn(() {
        return isar.isarConvertJobs
            .where()
            .statusEqualTo(.completed)
            .or()
            .statusEqualTo(.failed)
            .or()
            .statusEqualTo(.cancelled)
            .deleteAll();
      });
      return true;
    } catch (err, trace) {
      printError(err, trace);
      return false;
    }
  }

  @override
  Future<bool> removeOlderFinishedJobs(int dayCount) async {
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: dayCount));
    try {
      await isar.writeTxn(() {
        return isar.isarConvertJobs
            .where()
            .statusEqualTo(.completed)
            .or()
            .statusEqualTo(.failed)
            .or()
            .statusEqualTo(.cancelled)
            .filter()
            .updatedAtLessThan(cutoff)
            .deleteAll();
      });
      return true;
    } catch (err, trace) {
      printError(err, trace);
      return false;
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
          .statusEqualTo(.preparing)
          .findAll();
      final fixedJobs = invalidIsarJobs
          .map(
            (e) => e.toOriginalModel().copyWith(
              status: const Some(.pending),
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
    return isar.isarConvertJobs
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
        .watch(fireImmediately: true)
        .map((list) => list.isNotEmpty);
  }
}
