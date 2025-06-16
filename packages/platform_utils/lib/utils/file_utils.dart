import 'package:core/core.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:platform_utils/platform_utils.dart';

class FileUtils {
  static Future<bool> checkOutputWritability({
    required String outputFolderPath,
    required String fileName,
  }) async {
    final outputFolder = await DocumentFile.fromUri(outputFolderPath);
    if (outputFolder == null || !outputFolder.isDirectory) {
      return false;
    }

    final listFiles = await outputFolder.listDocuments(nameContains: fileName);
    for (final file in listFiles) {
      if (file.name == fileName) {
        return false;
      }
    }

    return true;
  }

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

  /// Return folder path and folder name.
  static Future<(String?, String?)> chooseSavePath(
    BuildContext context, {
    String? initialPath,
  }) async {
    try {
      if (Platform.isAndroid) {
        final DocumentFile? result = await DocMan.pick.directory(
          initDir: initialPath,
        );
        if (result == null || !result.isDirectory || !result.canWrite) {
          return (null, null);
        }
        return (result.uri, result.name);
      }

      final path = await FilePicker.platform.getDirectoryPath(
        initialDirectory: initialPath,
      );
      if (path == null || path.isEmpty) {
        return (null, null);
      }
      await Directory(path).createIfNotExists();

      return (path, basename(path));
    } catch (err, trace) {
      printError(err, trace);
      return (null, null);
    }
  }

  static Future<bool> moveTempFileToPath({
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

    if (Platform.isAndroid) {
      final DocumentFile? directory = await DocumentFile.fromUri(
        path,
      );
      if (directory == null || !directory.isDirectory || !directory.canWrite) {
        return false;
      }

      final result = await directory.createFile(
        name: fileName,
        bytes: await tempFile.readAsBytes(),
      );

      if (result == null) {
        return false;
      }
      await tempFile.delete();
      return true;
    }

    await tempFile.rename(path);
    return true;
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
}

extension DirectoryExtension on Directory {
  Future<Directory> createIfNotExists() async {
    if (!await exists()) {
      await create(recursive: true);
    }
    return this;
  }
}
