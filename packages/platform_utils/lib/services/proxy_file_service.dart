import 'package:core/core.dart';
import 'package:flutter/widgets.dart';
import 'package:platform_utils/platform_utils.dart';

class ProxyFileService implements FileService {
  final FileService _safService;
  final FileService _directService;
  final bool Function() _useSaf;

  ProxyFileService({
    required FileService safService,
    required FileService directService,
    required bool Function() useSaf,
  })  : _safService = safService,
        _directService = directService,
        _useSaf = useSaf;

  FileService get _delegate => _useSaf() ? _safService : _directService;

  @override
  Future<bool> isFileExist(String path) => _delegate.isFileExist(path);

  @override
  Future<List<File>> chooseFiles(BuildContext context) =>
      _delegate.chooseFiles(context);

  @override
  Future<(String?, Failure?)> chooseSavePath(
    BuildContext context, {
    String? initialPath,
  }) =>
      _delegate.chooseSavePath(context, initialPath: initialPath);

  @override
  Future<Failure?> moveConvertedFileToPath({
    required String convertedFilePath,
    required String outputFileName,
    required String outputFilePath,
  }) =>
      _delegate.moveConvertedFileToPath(
        convertedFilePath: convertedFilePath,
        outputFileName: outputFileName,
        outputFilePath: outputFilePath,
      );

  @override
  Future<(String?, Failure?)> copyTempOutputFileToConverted({
    required String jobId,
    required String convertedFilePath,
  }) =>
      _delegate.copyTempOutputFileToConverted(
        jobId: jobId,
        convertedFilePath: convertedFilePath,
      );

  @override
  Future<void> prepareConvertTempFolder({required String jobId}) =>
      _delegate.prepareConvertTempFolder(jobId: jobId);

  @override
  Future<Directory> getAppDataDirectory() => _delegate.getAppDataDirectory();

  @override
  Future<Directory> getConvertedDirectory(String prefix) =>
      _delegate.getConvertedDirectory(prefix);

  @override
  Future<Directory> getConvertTemporaryDirectory(String? prefix) =>
      _delegate.getConvertTemporaryDirectory(prefix);

  @override
  Future<void> cleanTemporaryDirectory() =>
      _delegate.cleanTemporaryDirectory();

  @override
  Future<bool> isDirectoryWritable(Directory dir) =>
      _delegate.isDirectoryWritable(dir);

  @override
  Future<Directory> getInputDirectory(String prefix) =>
      _delegate.getInputDirectory(prefix);

  @override
  Future<String?> movePickedFileToInputFolder({
    required String jobId,
    required String inputFilePath,
    required String appCachedPath,
  }) =>
      _delegate.movePickedFileToInputFolder(
        jobId: jobId,
        inputFilePath: inputFilePath,
        appCachedPath: appCachedPath,
      );

  @override
  Future<void> cleanUpInputFile({required String jobId}) =>
      _delegate.cleanUpInputFile(jobId: jobId);

  @override
  Future<void> deleteFileAtPath(String convertedFilePath) =>
      _delegate.deleteFileAtPath(convertedFilePath);

  @override
  Future<String?> getFileMimeType(File file) =>
      _delegate.getFileMimeType(file);

  @override
  Future<bool> isMediaFile(File file) => _delegate.isMediaFile(file);
}
