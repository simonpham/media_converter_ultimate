import 'package:converter/constants/strings.dart'
    show kDefaultOutputDirectoryName, kDefaultOutputDirectoryPath;
import 'package:converter/converter.dart' show kStoragePaths;
import 'package:core/core.dart';
import 'package:platform_utils/platform_utils.dart';

class JobMakerPathUtils {
  static FileService get _fileService => injector<FileService>();

  static Future<String?> getDefaultOutputDirectoryPath() async {
    if (Platform.isAndroid) {
      final destination = await _fileService.getDownloadsDestination();
      if (destination != null) return destination;

      for (final path in kStoragePaths) {
        final directory = Directory(path + kDefaultOutputDirectoryPath);
        await directory.createIfNotExists();
        final isWritable = await _fileService.isDirectoryWritable(directory);
        if (isWritable) return directory.path;
      }

      return OutputDestination.appStorage;
    }

    final docs = await getApplicationDocumentsDirectory();
    final directory = Directory('${docs.path}/$kDefaultOutputDirectoryName');
    await directory.createIfNotExists();
    return directory.path;
  }
}
