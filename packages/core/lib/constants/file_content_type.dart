import 'package:platform_utils/platform_utils.dart';

const headerBytesLength = 1024;

enum FileContentType {
  audio,
  video,
  other;

  factory FileContentType.fromMimeType(String? mimeType) {
    if (mimeType == null) {
      return FileContentType.other;
    }

    if (mimeType.startsWith('audio/')) {
      return FileContentType.audio;
    }

    if (mimeType.startsWith('video/')) {
      return FileContentType.video;
    }

    return FileContentType.other;
  }

  factory FileContentType.fromFile(File file) {
    final raf = file.openSync();
    final length = file.lengthSync();
    final headerBytes = raf.readSync(
      length < headerBytesLength ? length : headerBytesLength,
    );
    raf.closeSync();
    final mimeType = lookupMimeType(file.path, headerBytes: headerBytes);
    return FileContentType.fromMimeType(mimeType);
  }

  static Future<String?> getMimeType(File file) async {
    try {
      final headerBytes = await file
          .openRead(0, defaultMagicNumbersMaxLength)
          .first;
      return lookupMimeType(file.path, headerBytes: headerBytes);
    } catch (_) {
      return null;
    }
  }
}
