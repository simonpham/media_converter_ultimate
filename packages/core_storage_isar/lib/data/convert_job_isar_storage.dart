import 'dart:async';

import 'package:core/core.dart';
import 'package:core_storage_base/core_storage_base.dart';
import 'package:core_storage_isar/core_storage_isar.dart';

class ConvertJobIsarStorage extends ConvertJobStorage {
  final Isar isar;

  const ConvertJobIsarStorage({
    required this.isar,
  });

  @override
  Future<List<ConvertJob>> getJobs(Pagination pagination) async {
    final jobs = await isar.isarConvertJobs.where().findAll();
    return jobs.map((job) => job.toOriginalModel()).toList();
  }
}
