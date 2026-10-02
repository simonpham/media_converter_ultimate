import 'package:platform_utils/platform_utils.dart';

class TestPreviewSession implements MediaPreviewSession {
  @override
  Future<PreviewMediaInfo> inspect(String path) async =>
      const PreviewMediaInfo(Duration(seconds: 10));
  @override
  Stream<Duration> get positions => const Stream.empty();
  @override
  Stream<void> get completed => const Stream.empty();
  @override
  Duration get audioEnd => Duration.zero;
  @override
  Future<String?> frame(String path, Duration position) async => null;
  @override
  Future<String?> thumbnails(
    String path,
    Duration start,
    Duration length,
  ) async => null;
  @override
  Future<String?> waveform(
    String path,
    Duration start,
    Duration length,
    String color,
  ) async => null;
  @override
  Future<bool> play(String path, Duration start, Duration end) async => false;
  @override
  Future<void> pause() async {}
  @override
  Future<void> close() async {}
}
