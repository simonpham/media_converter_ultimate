import 'package:core/core.dart';
import 'package:core_storage_isar/core_storage_isar.dart';

extension ConvertJobIsarMapperExt on ConvertJob {
  IsarConvertJob toIsarModel() {
    return IsarConvertJob(
      id: id,
      inputFilePath: inputFilePath,
      outputFileName: outputFileName,
      outputDirectoryPath: outputDirectoryPath,
      command: command,
      createdAt: createdAt,
      updatedAt: updatedAt,
      sessionId: sessionId,
      status: status,
      progress: progress,
      duration: duration,
    );
  }
}

extension IsarConvertJobMapperExt on IsarConvertJob {
  ConvertJob toOriginalModel() {
    return ConvertJob(
      id: id,
      inputFilePath: inputFilePath,
      outputFileName: outputFileName,
      outputDirectoryPath: outputDirectoryPath,
      command: command,
      createdAt: createdAt,
      updatedAt: updatedAt,
      sessionId: sessionId,
      status: status,
      progress: progress,
      duration: duration,
    );
  }
}
