import 'dart:async';

import 'package:core/core.dart';
import 'package:core_storage_base/core_storage_base.dart';
import 'package:core_storage_isar/core_storage_isar.dart';
import 'package:utils/utils.dart';

class ConvertJobIsarStorage extends ConvertJobStorage {
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
    final jobs = await isar.isarConvertJobs.where().findAll();
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
}
