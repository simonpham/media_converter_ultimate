import 'package:core/core.dart' show Failure;
import 'package:platform_utils/platform_utils.dart'
    show Directory, File, ExportedFile;

abstract class FileService {
  /// Resolves a supported Downloads destination without changing remembered folders.
  Future<String?> getDownloadsDestination();

  Future<bool> outputExists(String destination, String name);

  /// Retains the staged source until the caller has persisted the returned location.
  Future<(ExportedFile?, Failure?)> exportFile({
    required String exportId,
    required String source,
    required String destination,
    required String name,
  });

  Future<ExportedFile?> recoverExport(String exportId);
  Future<void> acknowledgeExport(String exportId);
  Future<void> openOutput(String location);
  Future<void> shareOutput(String location);
  Future<void> deleteOutput(String location);

  Future<bool> isFileExist(String path);

  Future<List<File>> chooseFiles(dynamic context);

  Future<(String?, Failure?)> chooseSavePath(
    dynamic context, {
    String? initialPath,
  });

  Future<Failure?> moveConvertedFileToPath({
    required String convertedFilePath,
    required String outputFileName,
    required String outputFilePath,
  });

  Future<(String?, Failure?)> copyTempOutputFileToConverted({
    required String jobId,
    required String convertedFilePath,
  });

  Future<void> prepareConvertTempFolder({
    required String jobId,
  });

  Future<Directory> getAppDataDirectory();
  Future<Directory> getAppCacheDirectory();

  Future<Directory> getConvertedDirectory(String prefix);

  Future<Directory> getConvertTemporaryDirectory(String? prefix);

  Future<void> cleanTemporaryDirectory();

  Future<bool> isDirectoryWritable(Directory dir);

  Future<Directory> getInputDirectory(String prefix);

  Future<String?> movePickedFileToInputFolder({
    required String jobId,
    required String inputFilePath,
    required String appCachedPath,
  });

  /// Rolls back an unsubmitted input, returning its accessible path. If the
  /// picker cache cannot be restored, the prepared copy remains recoverable.
  Future<String?> restorePickedFile({
    required String jobId,
    required String originalFilePath,
    required String preparedFilePath,
  });

  Future<void> cleanUpInputFile({
    required String jobId,
  });

  Future<void> deleteFileAtPath(String convertedFilePath);

  Future<String?> getFileMimeType(File file);

  Future<bool> isMediaFile(File file);
}
