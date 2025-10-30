import 'package:converter/constants/strings.dart'
    show kDefaultOutputDirectoryPath;
import 'package:converter/converter.dart' show kStoragePaths;
import 'package:core/core.dart';
import 'package:platform_utils/platform_utils.dart';

class JobMakerPathUtils {
  static FileService get _fileService => injector<FileService>();

  static Future<String?> getDefaultOutputDirectoryPath() async {
    for (final path in kStoragePaths) {
      final directory = Directory(path + kDefaultOutputDirectoryPath);
      await directory.createIfNotExists();
      final isWritable = await _fileService.isDirectoryWritable(directory);
      if (!isWritable) {
        continue;
      }

      return directory.path;
    }
    return null;
  }
}
