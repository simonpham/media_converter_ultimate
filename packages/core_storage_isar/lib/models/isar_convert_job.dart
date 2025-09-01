import 'package:core/core.dart';
import 'package:core_storage_isar/core_storage_isar.dart';
import 'package:utils/utils.dart';

part 'isar_convert_job.g.dart';

@collection
class IsarConvertJob {
  Id get isarId => fastHash(id);

  final String id;
  final String inputFilePath;
  final String outputFileName;
  final String outputExtension;
  final String outputDirectoryPath;
  final String command;
  final String convertedFilePath;

  @Index()
  final DateTime createdAt;
  @Index()
  final DateTime updatedAt;

  final int? sessionId;
  @Index()
  @Enumerated(EnumType.name)
  final JobStatus status;
  final int? progress;
  final int? duration;

  const IsarConvertJob({
    required this.id,
    required this.inputFilePath,
    required this.outputFileName,
    required this.outputExtension,
    required this.outputDirectoryPath,
    required this.command,
    required this.convertedFilePath,
    required this.createdAt,
    required this.updatedAt,
    this.sessionId,
    this.status = JobStatus.pending,
    this.progress,
    this.duration,
  });
}
