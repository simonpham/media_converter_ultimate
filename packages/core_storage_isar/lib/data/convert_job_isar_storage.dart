import 'dart:async';

import 'package:core/core.dart';
import 'package:core_storage_base/core_storage_base.dart';
import 'package:core_storage_isar/core_storage_isar.dart';
import 'package:platform_utils/platform_utils.dart';
import 'package:utils/utils.dart';

class ConvertJobIsarStorage extends ConvertJobStorage {
  static Future<Isar> createIsarInstance() async {
    final dataFolder = await FileUtils.getAppDataDirectory();
    return await Isar.open(
      [IsarConvertJobSchema],
      directory: dataFolder.path,
    );
  }

  final Isar isar;

  const ConvertJobIsarStorage({
    required this.isar,
  });

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
  Future<List<ConvertJob>> list(Pagination pagination) async {
    final (offset, limit) = switch (pagination) {
      OffsetLimitPagination p => (p.offset, p.limit),
      _ => (0, 0),
    };
    final jobs = await isar.isarConvertJobs
        .where()
        .sortByCreatedAtDesc()
        .offset(offset)
        .limit(limit)
        .findAll();
    return jobs.map((job) => job.toOriginalModel()).toList();
  }

  @override
  Future<Failure?> update(ConvertJob item) async {
    final convertedItem = item.toIsarModel();
    await isar.writeTxn(() {
      return isar.isarConvertJobs.put(convertedItem);
    });
    return null;
  }

  @override
  void onDispose() {
    isar.close();
  }

  @override
  Stream<List<ConvertJob>> watchCompletedJobs() {
    return isar.isarConvertJobs
        .where()
        .statusEqualTo(JobStatus.completed)
        .or()
        .statusEqualTo(JobStatus.failed)
        .or()
        .statusEqualTo(JobStatus.cancelled)
        .sortByCreatedAtDesc()
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
        .statusEqualTo(JobStatus.pending)
        .sortByCreatedAtDesc()
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
        .statusEqualTo(JobStatus.running)
        .or()
        .statusEqualTo(JobStatus.preparing)
        .or()
        .statusEqualTo(JobStatus.ready)
        .sortByCreatedAtDesc()
        .watch(fireImmediately: true)
        .map(
          (list) => list
              .whereType<IsarConvertJob>()
              .map((e) => e.toOriginalModel())
              .toList(),
        );
  }
}
