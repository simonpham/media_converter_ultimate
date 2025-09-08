import 'package:platform_utils/platform_utils.dart';

extension FileExtensions on File {
  String get fileName => basename(path);

  String get fileExtension {
    final ext = extension(path);
    if (ext.isEmpty) {
      return '';
    }
    if (ext.startsWith('.')) {
      return ext.substring(1);
    }
    return ext;
  }
}
