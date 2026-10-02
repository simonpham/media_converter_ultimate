import 'package:core/core.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:platform_utils/platform_utils.dart';

class DirectFileService implements FileService {
  DirectFileService({AndroidOutputStorage? androidStorage, bool? isAndroid})
    : _androidStorage = androidStorage ?? const AndroidOutputStorage(),
      _isAndroid = isAndroid ?? Platform.isAndroid;

  final AndroidOutputStorage _androidStorage;
  final bool _isAndroid;

  @override
  Future<String?> getDownloadsDestination() async {
    if (_isAndroid && await _androidStorage.supportsDownloads()) {
      return OutputDestination.downloads;
    }
    if (_isAndroid) {
      final directory = Directory(
        '/storage/emulated/0/Download/MediaConverterPro',
      );
      try {
        await createIfNotExists(directory);
        return await isDirectoryWritable(directory) ? directory.path : null;
      } catch (error, trace) {
        printError(error, trace);
        return null;
      }
    }
    return null;
  }

  Future<String> _directoryPath(OutputDestination destination) async =>
      destination.kind == .appStorage
      ? (await getConvertedDirectory('exports')).path
      : destination.location;

  @override
  Future<bool> outputExists(String destination, String name) async {
    final target = OutputDestination.parse(destination);
    if (target.kind == .tree || target.kind == .downloads) {
      try {
        return await _androidStorage.contains(target.location, name);
      } on PlatformException catch (error) {
        throw AndroidOutputStorage.failure(error, name);
      }
    }
    return isFileExist(path.join(await _directoryPath(target), name));
  }

  @override
  Future<(ExportedFile?, Failure?)> exportFile({
    required String exportId,
    required String source,
    required String destination,
    required String name,
  }) async {
    try {
      if (name.isEmpty ||
          name == '.' ||
          name == '..' ||
          name.contains('/') ||
          name.contains('\\')) {
        return (null, FileNameIsNotSetFailure(name));
      }
      if (!await File(source).exists()) {
        return (null, InputFileNotExistFailure(source));
      }
      final target = OutputDestination.parse(destination);
      if (target.kind == .tree || target.kind == .downloads) {
        final exported = await _androidStorage.export(
          id: exportId,
          source: source,
          name: name,
          destination: target.location,
          mime: lookupMimeType(name),
        );
        return (exported, null);
      }
      final directory = Directory(await _directoryPath(target));
      await createIfNotExists(directory);
      final output = File(path.join(directory.path, name));
      if (await output.exists()) {
        return (null, OutputFileAlreadyExistsFailure(output.path));
      }
      try {
        await output.create(exclusive: true);
      } on FileSystemException {
        if (await output.exists()) {
          return (null, OutputFileAlreadyExistsFailure(output.path));
        }
        rethrow;
      }
      try {
        await File(source).copy(output.path);
      } catch (error, trace) {
        if (await output.exists()) await output.delete();
        Error.throwWithStackTrace(error, trace);
      }
      return (ExportedFile(location: output.path, name: name), null);
    } on PlatformException catch (error) {
      return (null, AndroidOutputStorage.failure(error, name));
    } catch (error, trace) {
      printError(error, trace);
      return (null, const OutputExportFailure());
    }
  }

  @override
  Future<ExportedFile?> recoverExport(String exportId) async =>
      _isAndroid ? await _androidStorage.recover(exportId) : null;

  @override
  Future<void> acknowledgeExport(String exportId) async {
    if (_isAndroid) await _androidStorage.acknowledge(exportId);
  }

  @override
  Future<void> openOutput(String location) async {
    if (location.startsWith('content://')) {
      await _androidStorage.open(location);
    } else if (!await launchUrl(Uri.file(location))) {
      throw StateError('No application can open this file');
    }
  }

  @override
  Future<void> shareOutput(String location) => location.startsWith('content://')
      ? _androidStorage.share(location)
      : File(location).share();

  @override
  Future<void> deleteOutput(String location) =>
      location.startsWith('content://')
      ? _androidStorage.delete(location)
      : File(location).delete();

  @override
  Future<bool> isFileExist(String filePath) async {
    if (filePath.startsWith('content://')) {
      return _androidStorage.exists(filePath);
    }
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
      if (_isAndroid) {
        final target = initialPath == null
            ? null
            : OutputDestination.parse(initialPath);
        final selected = await _androidStorage.pickTree(
          target?.kind == .tree ? target!.location : null,
        );
        return (selected, null);
      }
      final folderPath = await FilePicker.getDirectoryPath(
        initialDirectory: initialPath,
      );
      if (folderPath == null || folderPath.isEmpty) return (null, null);
      final dir = await createIfNotExists(Directory(folderPath));
      if (!await isDirectoryWritable(dir)) {
        return (null, DirectoryNotWritableFailure(folderPath));
      }
      return (folderPath, null);
    } on PlatformException catch (error) {
      return (null, AndroidOutputStorage.failure(error, initialPath ?? ''));
    } catch (error, trace) {
      printError(error, trace);
      return (null, const OutputExportFailure());
    }
  }

  @override
  Future<Failure?> moveConvertedFileToPath({
    required String convertedFilePath,
    required String outputFileName,
    required String outputFilePath,
  }) async {
    final id = 'export-${DateTime.now().microsecondsSinceEpoch}';
    final (exported, failure) = await exportFile(
      exportId: id,
      source: convertedFilePath,
      destination: outputFilePath,
      name: outputFileName,
    );
    if (failure != null || exported == null) {
      return failure ?? const OutputExportFailure();
    }
    await acknowledgeExport(id);
    await deleteFileAtPath(convertedFilePath);
    return null;
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
    if (!path.isWithin(
      path.join(appCachedPath, 'file_picker'),
      inputFilePath,
    )) {
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
  Future<String?> restorePickedFile({
    required String jobId,
    required String originalFilePath,
    required String preparedFilePath,
  }) async {
    final prepared = File(preparedFilePath);
    final original = File(originalFilePath);
    try {
      if (!await prepared.exists()) {
        return await original.exists() ? originalFilePath : null;
      }
      final inputFolder = await getInputDirectory(jobId);
      final cache = await getAppCacheDirectory();
      final pickerCache = path.join(cache.path, 'file_picker');
      if (!path.isWithin(inputFolder.path, preparedFilePath) ||
          !path.isWithin(pickerCache, originalFilePath)) {
        return preparedFilePath;
      }
      // A newer picker result may have reused the original cache path. Never
      // overwrite it; recover this batch's bytes under a separate cache path.
      final target = await original.exists()
          ? File(
              path.join(
                pickerCache,
                'recovered-$jobId',
                path.basename(originalFilePath),
              ),
            )
          : original;
      if (await target.exists()) return preparedFilePath;
      await target.parent.create(recursive: true);
      try {
        await prepared.rename(target.path);
      } catch (_) {
        try {
          await prepared.copy(target.path);
        } catch (error, trace) {
          if (await target.exists()) await target.delete();
          Error.throwWithStackTrace(error, trace);
        }
        try {
          await prepared.delete();
        } catch (error, trace) {
          printError(error, trace);
        }
      }
      await cleanUpInputFile(jobId: jobId);
      return target.path;
    } catch (error, trace) {
      printError(error, trace);
      if (await prepared.exists()) return preparedFilePath;
      return await original.exists() ? originalFilePath : null;
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
    try {
      final headerBytes = await file
          .openRead(0, defaultMagicNumbersMaxLength)
          .fold<List<int>>([], (bytes, chunk) => bytes..addAll(chunk));
      return lookupMimeType(file.path, headerBytes: headerBytes);
    } on FileSystemException catch (error, trace) {
      printError(error, trace);
      return null;
    }
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
