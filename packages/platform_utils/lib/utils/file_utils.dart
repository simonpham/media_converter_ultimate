import 'package:core/core.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:platform_utils/platform_utils.dart';

class FileUtils {
  static Future<bool> isFileExist(String path) async {
    return await File(path).exists();
  }

  static Future<List<File>> chooseFiles(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );

      final files = result?.files;
      if (files == null || files.isEmpty) {
        return const [];
      }

      return files
          .map(
            (file) {
              final path = file.path;
              if (path == null || path.isEmpty) {
                return null;
              }
              return File(path);
            },
          )
          .nonNulls
          .toList();
    } catch (err, trace) {
      printError(err, trace);

      return const [];
    }
  }

  /// Return folder path.
  static Future<(String?, Failure?)> chooseSavePath(
    BuildContext context, {
    String? initialPath,
  }) async {
    try {
      final path = await FilePicker.platform.getDirectoryPath(
        initialDirectory: initialPath,
      );
      if (path == null || path.isEmpty) {
        return (null, null);
      }

      final dir = Directory(path);
      await dir.createIfNotExists();

      final isWritable = await isDirectoryWritable(dir);
      if (!isWritable) {
        return (null, DirectoryNotWritableFailure(path));
      }

      return (path, null);
    } catch (err, trace) {
      printError(err, trace);
      return (null, null);
    }
  }

  static Future<Failure?> moveConvertedFileToPath({
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
      await dir.createIfNotExists();

      final outputPath = join(dir.path, outputFileName);
      if (await File(outputPath).exists()) {
        return OutputFileAlreadyExistsFailure(outputPath);
      }

      await tempFile.copy(outputPath);
      await tempFile.delete();
      return null;
    } catch (err, trace) {
      printError(err, trace);
      return Failure(err.toString());
    }
  }

  static Future<(String?, Failure?)> copyTempOutputFileToConverted({
    required String jobId,
    required String convertedFilePath,
  }) async {
    try {
      final fileName = basename(convertedFilePath);
      final inputFile = File(convertedFilePath);
      if (!await inputFile.exists()) {
        return (null, InputFileNotExistFailure(convertedFilePath));
      }
      final convertedFolder = await FileUtils.getConvertedDirectory(jobId);
      final outputFile = File(
        join(convertedFolder.path, fileName),
      );
      await inputFile.copy(outputFile.path);
      return (outputFile.path, null);
    } catch (err, trace) {
      printError(err, trace);
      return (null, Failure(err.toString()));
    }
  }

  static Future<void> prepareConvertTempFolder({
    required String jobId,
  }) async {
    final tempDir = await FileUtils.getConvertTemporaryDirectory(jobId);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }

    await tempDir.create(recursive: true);
  }

  static Future<Directory> getAppDataDirectory() async {
    final docFolder = await path_provider.getApplicationDocumentsDirectory();
    final dataFolder = Directory(
      path.join(docFolder.path, kDataFolderName),
    );
    return dataFolder.createIfNotExists();
  }

  /// Return a Directory used for [JobStatus.actionRequired].
  /// Successful conversion but failed to copy to output folder
  /// will be moved to [getConvertedDirectory].
  static Future<Directory> getConvertedDirectory(String prefix) async {
    final docFolder = await path_provider.getApplicationDocumentsDirectory();
    final convertedFolder = Directory(
      path.join(
        docFolder.path,
        kConvertDataFolderName,
        kConvertedFolderName,
        prefix,
      ),
    );
    return convertedFolder.createIfNotExists();
  }

  static Future<Directory> getConvertTemporaryDirectory(String? prefix) async {
    final tempFolder = await path_provider.getTemporaryDirectory();
    final convertTempFolder = Directory(
      path.join(
        tempFolder.path,
        kConvertDataFolderName,
        kConvertTempFolderName,
        prefix,
      ),
    );
    return convertTempFolder.createIfNotExists();
  }

  static Future<void> cleanConvertTemporaryDirectory() async {
    final tempFolder = await getConvertTemporaryDirectory(null);
    await tempFolder.delete(recursive: true);
  }

  static Future<bool> isDirectoryWritable(Directory dir) async {
    try {
      if (!await dir.exists()) {
        return false;
      }

      final stat = await dir.stat();
      if (stat.type != FileSystemEntityType.directory) {
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
}

extension FileExtension on File {
  Future<void> share() async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(this.path)],
      ),
    );
  }
}

extension DirectoryExtension on Directory {
  Future<Directory> createIfNotExists() async {
    if (!await exists()) {
      await create(recursive: true);
    }
    return this;
  }
}
