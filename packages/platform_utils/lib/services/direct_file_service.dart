import 'package:core/core.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:platform_utils/platform_utils.dart';

class DirectFileService implements FileService {
  @override
  Future<bool> isFileExist(String filePath) async {
    return await File(filePath).exists();
  }

  @override
  Future<List<File>> chooseFiles(dynamic context) async {
    try {
      final files = await FilePicker.pickFiles(
        type: .any,
      );

      if (files.isEmpty) {
        return const [];
      }

      return files
          .map(
            (file) {
              final filePath = file.path;
              if (filePath == null || filePath.isEmpty) {
                return null;
              }
              return File(filePath);
            },
          )
          .nonNulls
          .toList();
    } catch (err, trace) {
      printError(err, trace);

      return const [];
    }
  }

  @override
  Future<(String?, Failure?)> chooseSavePath(
    dynamic context, {
    String? initialPath,
  }) async {
    try {
      final folderPath = await FilePicker.getDirectoryPath(
        initialDirectory: initialPath,
      );
      if (folderPath == null || folderPath.isEmpty) {
        printLog('[DirectFileService] chooseSavePath: empty folderPath');
        return (null, const NoOutputFolderFailure());
      }

      final dir = Directory(folderPath);
      await createIfNotExists(dir);

      final isWritable = await isDirectoryWritable(dir);
      if (!isWritable) {
        return (null, DirectoryNotWritableFailure(folderPath));
      }

      return (folderPath, null);
    } catch (err, trace) {
      printError(err, trace);
      return (null, null);
    }
  }

  @override
  Future<Failure?> moveConvertedFileToPath({
    required String convertedFilePath,
    required String outputFileName,
    required String outputFilePath,
  }) async {
    try {
      final tempFile = File(convertedFilePath);
      if (!await tempFile.exists()) {
        return InputFileNotExistFailure(convertedFilePath);
      }

      final dir = Directory(outputFilePath);
      await createIfNotExists(dir);

      final outputPath = path.join(dir.path, outputFileName);
      if (await File(outputPath).exists()) {
        return OutputFileAlreadyExistsFailure(outputPath);
      }

      try {
        await tempFile.rename(outputPath);
      } catch (_) {
        await tempFile.copy(outputPath);
        await tempFile.delete();
      }
      return null;
    } catch (err, trace) {
      printError(err, trace);
      return Failure(err.toString());
    }
  }

  @override
  Future<(String?, Failure?)> copyTempOutputFileToConverted({
    required String jobId,
    required String convertedFilePath,
  }) async {
    try {
      final fileName = path.basename(convertedFilePath);
      final inputFile = File(convertedFilePath);
      if (!await inputFile.exists()) {
        return (null, InputFileNotExistFailure(convertedFilePath));
      }
      final convertedFolder = await getConvertedDirectory(jobId);
      final outputFile = File(
        path.join(convertedFolder.path, fileName),
      );
      if (path.equals(inputFile.absolute.path, outputFile.absolute.path)) {
        return (outputFile.path, null);
      }
      await inputFile.copy(outputFile.path);
      return (outputFile.path, null);
    } catch (err, trace) {
      printError(err, trace);
      return (null, Failure(err.toString()));
    }
  }

  @override
  Future<void> prepareConvertTempFolder({
    required String jobId,
  }) async {
    final tempDir = await getConvertTemporaryDirectory(jobId);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
    await tempDir.create(recursive: true);
  }

  @override
  Future<Directory> getAppCacheDirectory() =>
      path_provider.getApplicationCacheDirectory();

  @override
  Future<Directory> getAppDataDirectory() async {
    final docFolder = await path_provider.getApplicationDocumentsDirectory();
    final dataFolder = Directory(
      path.join(docFolder.path, kDataFolderName),
    );
    return createIfNotExists(dataFolder);
  }

  @override
  Future<Directory> getConvertedDirectory(String prefix) async {
    final docFolder = await path_provider.getApplicationDocumentsDirectory();
    final convertedFolder = Directory(
      path.join(
        docFolder.path,
        kConvertDataFolderName,
        kConvertedFolderName,
        prefix,
      ),
    );
    return createIfNotExists(convertedFolder);
  }

  @override
  Future<Directory> getConvertTemporaryDirectory(String? prefix) async {
    final tempFolder = await path_provider.getTemporaryDirectory();
    final convertTempFolder = Directory(
      path.join(
        tempFolder.path,
        kConvertDataFolderName,
        kConvertTempFolderName,
        prefix,
      ),
    );
    return createIfNotExists(convertTempFolder);
  }

  @override
  Future<void> cleanTemporaryDirectory() async {
    final tempFolder = await getConvertTemporaryDirectory(null);
    await tempFolder.delete(recursive: true);
  }

  @override
  Future<bool> isDirectoryWritable(Directory dir) async {
    try {
      if (!await dir.exists()) {
        return false;
      }

      final stat = await dir.stat();
      if (stat.type != .directory) {
        return false;
      }

      final testFile = File(
        path.join(dir.path, '.${DateTime.now().millisecondsSinceEpoch}.mcu'),
      );
      await testFile.create(recursive: true);
      await testFile.delete();
    } catch (err, trace) {
      printError(err, trace);
      return false;
    }

    return true;
  }

  @override
  Future<Directory> getInputDirectory(String prefix) async {
    final docFolder = await path_provider.getApplicationDocumentsDirectory();
    final inputFolder = Directory(
      path.join(
        docFolder.path,
        kConvertDataFolderName,
        kInputFolderName,
        prefix,
      ),
    );
    return createIfNotExists(inputFolder);
  }

  @override
  Future<String?> movePickedFileToInputFolder({
    required String jobId,
    required String inputFilePath,
    required String appCachedPath,
  }) async {
    if (!inputFilePath.startsWith('$appCachedPath/file_picker/')) {
      printLog(
        '[DirectFileService] movePickedFileToInputFolder: file not in file_picker cache. Skipping.',
      );
      return inputFilePath;
    }
    try {
      final inputFolder = await getInputDirectory(jobId);
      final inputFile = File(inputFilePath);
      final inputFileName = path.basename(inputFilePath);
      final newInputFilePath = path.join(
        inputFolder.path,
        inputFileName,
      );
      try {
        await inputFile.rename(newInputFilePath);
      } catch (_) {
        await inputFile.copy(newInputFilePath);
        await inputFile.delete();
      }
      return newInputFilePath;
    } catch (err, trace) {
      printError(err, trace);
      return null;
    }
  }

  @override
  Future<void> cleanUpInputFile({
    required String jobId,
  }) async {
    try {
      final inputDir = await getInputDirectory(jobId);
      await inputDir.delete(recursive: true);
    } catch (err, trace) {
      printError(err, trace);
    }
  }

  @override
  Future<void> deleteFileAtPath(String convertedFilePath) async {
    try {
      await File(convertedFilePath).delete();
    } catch (err, trace) {
      printError(err, trace);
    }
  }

  @override
  Future<String?> getFileMimeType(File file) async {
    final headerBytes = await file
        .openRead(0, defaultMagicNumbersMaxLength)
        .first;
    return lookupMimeType(file.path, headerBytes: headerBytes);
  }

  @override
  Future<bool> isMediaFile(File file) async {
    final mimeType = await getFileMimeType(file);
    if (mimeType == null) {
      return false;
    }
    return mimeType.startsWith('video/') || mimeType.startsWith('audio/');
  }

  // Helper for Directory extension method
  Future<Directory> createIfNotExists(Directory dir) async {
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
