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

  static Future<bool> moveTempFileToPath({
    required String fileName,
    required String path,
  }) async {
    try {
      final tempDir = await FileUtils.getConvertTemporaryDirectory();
      final tempFile = File(
        join(tempDir.path, fileName),
      );
      if (!await tempFile.exists()) {
        return false;
      }

      final dir = Directory(path);
      await dir.createIfNotExists();

      await tempFile.copy(
        join(dir.path, fileName),
      );
      await tempFile.delete();
      return true;
    } catch (err, trace) {
      printError(err, trace);
      return false;
    }
  }

  static Future<bool> cleanUpTempFile({
    required String fileName,
    required String path,
  }) async {
    final tempDir = await FileUtils.getConvertTemporaryDirectory();
    final tempFile = File(
      join(tempDir.path, fileName),
    );
    if (!await tempFile.exists()) {
      return false;
    }

    await tempFile.delete();
    return true;
  }

  static Future<Directory> getAppDataDirectory() async {
    final tempFolder = await path_provider.getApplicationDocumentsDirectory();
    final dataFolder = Directory(
      path.join(tempFolder.path, kDataFolderName),
    );
    return dataFolder.createIfNotExists();
  }

  static Future<Directory> getConvertTemporaryDirectory() async {
    final tempFolder = await path_provider.getTemporaryDirectory();
    final convertTempFolder = Directory(
      path.join(tempFolder.path, kConvertTempFolderName),
    );
    return convertTempFolder.createIfNotExists();
  }

  static Future<void> cleanConvertTemporaryDirectory() async {
    final tempFolder = await getConvertTemporaryDirectory();
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
