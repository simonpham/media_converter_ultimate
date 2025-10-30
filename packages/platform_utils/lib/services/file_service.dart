import 'package:core/core.dart' show Failure;
import 'package:platform_utils/platform_utils.dart' show Directory, File;

abstract class FileService {
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

  Future<void> cleanUpInputFile({
    required String jobId,
  });

  Future<void> deleteFileAtPath(String convertedFilePath);

  Future<String?> getFileMimeType(File file);

  Future<bool> isMediaFile(File file);
}
