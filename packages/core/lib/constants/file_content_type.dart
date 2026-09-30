enum FileContentType {
  audio,
  video,
  other;

  factory FileContentType.fromMimeType(String? mimeType) {
    if (mimeType == null) {
      return .other;
    }

    if (mimeType.startsWith('audio/')) {
      return .audio;
    }

    if (mimeType.startsWith('video/')) {
      return .video;
    }

    return .other;
  }
}
