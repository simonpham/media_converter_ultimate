import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:core/core.dart';
import 'package:platform_utils/platform_utils.dart';

class const PreviewMediaInfo(
  final Duration duration, {
  final int? videoIndex,
  final int? audioIndex,
});

/// One owned preview session. Closing it stops only its own native work/player.
abstract class MediaPreviewSession {
  Stream<Duration> get positions;
  Stream<void> get completed;
  Duration get audioEnd;
  Future<PreviewMediaInfo> inspect(String path);
  Future<String?> frame(String path, Duration position);
  Future<String?> thumbnails(String path, Duration start, Duration length);
  Future<String?> waveform(
    String path,
    Duration start,
    Duration length,
    String color,
  );
  Future<bool> play(String path, Duration start, Duration end);
  Future<void> pause();
  Future<void> close();
}

class FfmpegMediaPreviewSession implements MediaPreviewSession {
  final _positions = StreamController<Duration>.broadcast();
  final _completed = StreamController<void>.broadcast();
  final _operations = <Future<void>>{};
  final _sessions = <int>{};
  final _images = <String>[];
  final _waveImages = <String>[];
  Directory? _directory;
  PreviewMediaInfo? _info;
  AudioPlayer? _player;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<void>? _completionSubscription;
  Duration _audioStart = Duration.zero;
  Duration _audioEnd = Duration.zero;
  int _revision = 0;
  int _fileNumber = 0;
  bool _closed = false;
  Future<void>? _closing;

  @override
  Stream<Duration> get positions => _positions.stream;
  @override
  Stream<void> get completed => _completed.stream;
  @override
  Duration get audioEnd => _audioEnd;

  Future<T> _track<T>(Future<T> Function() action) async {
    if (_closed) throw StateError('Preview is closed');
    final done = Completer<void>();
    _operations.add(done.future);
    try {
      return await action();
    } finally {
      done.complete();
      _operations.remove(done.future);
    }
  }

  @override
  Future<PreviewMediaInfo> inspect(String path) => _track(() async {
    final completion = Completer<MediaInformationSession>();
    await FFprobeKit.getMediaInformationAsync(
      path,
      (session) => completion.complete(session),
    );
    final media = (await completion.future).getMediaInformation();
    final seconds = double.tryParse('${media?.getDuration()}');
    if (seconds == null || !seconds.isFinite || seconds <= 0) {
      throw StateError('Preview requires a finite media duration');
    }
    final streams = <Map<dynamic, dynamic>>[
      for (final stream in media?.getStreams() ?? [])
        ?stream.getAllProperties(),
    ];
    final audio = streams.where((s) => s['codec_type'] == 'audio').toList();
    final preferred =
        audio.where((s) => s['disposition']?['default'] == 1).firstOrNull ??
        audio.firstOrNull;
    final video = streams
        .where(
          (s) =>
              s['codec_type'] == 'video' &&
              s['disposition']?['attached_pic'] != 1,
        )
        .firstOrNull;
    _info = PreviewMediaInfo(
      Duration(milliseconds: (seconds * 1000).round().clamp(1, 1 << 62)),
      videoIndex: video?['index'] as int?,
      audioIndex: preferred?['index'] as int?,
    );
    _directory = await (await injector<FileService>().getAppCacheDirectory())
        .createTemp('trim_preview_');
    return _info!;
  });

  Future<void> _encode(List<String> arguments) async {
    final completion = Completer<FFmpegSession>();
    final session = await FFmpegKit.executeWithArgumentsAsync(
      [
        '-v',
        'warning',
        '-nostdin',
        '-y',
        '-threads',
        '1',
        '-filter_threads',
        '1',
        ...arguments,
      ],
      (session) => completion.complete(session),
    );
    final id = session.getSessionId();
    if (id != null) _sessions.add(id);
    try {
      if (_closed && id != null) await FFmpegKit.cancel(id);
      final finished = await completion.future;
      if (!ReturnCode.isSuccess(await finished.getReturnCode())) {
        throw StateError(
          'Preview generation failed: ${await finished.getOutput()}',
        );
      }
    } finally {
      _sessions.remove(id);
    }
  }

  String _newPath(String extension) =>
      join(_directory!.path, 'preview-${_fileNumber++}.$extension');

  Future<String?> _image(List<String> args, {bool wave = false}) async {
    final output = _newPath('png');
    await _encode([...args, '-frames:v', '1', '-update', '1', output]);
    if (!await File(output).exists()) return null;
    final images = wave ? _waveImages : _images;
    images.add(output);
    // Keep a few previous frames alive while Flutter loads the next image.
    if (images.length > 4) await File(images.removeAt(0)).delete();
    return output;
  }

  @override
  Future<String?> frame(String path, Duration position) => _track(() async {
    if (_info?.videoIndex == null) return null;
    final milliseconds = position.inMilliseconds.clamp(
      0,
      _info!.duration.inMilliseconds - 1,
    );
    List<String> arguments(int at) => [
      '-ss',
      (at / 1000).toStringAsFixed(3),
      '-i',
      path,
      '-map',
      '0:${_info!.videoIndex}',
      '-an',
      '-sn',
      '-vf',
      'scale=640:360:force_original_aspect_ratio=decrease',
    ];
    final image = await _image(arguments(milliseconds));
    // Seeking beyond the final frame can produce no image even before EOF.
    return image ??
        await _image(arguments((milliseconds - 100).clamp(0, milliseconds)));
  });

  @override
  Future<String?> thumbnails(String path, Duration start, Duration length) =>
      _track(() async {
        if (_info?.videoIndex == null) return null;
        final at = start.inMilliseconds.clamp(
          0,
          _info!.duration.inMilliseconds - 1,
        );
        final span = length.inMilliseconds
            .clamp(1, 30000)
            .clamp(1, _info!.duration.inMilliseconds - at);
        final seconds = (span / 1000).toStringAsFixed(3);
        return _image([
          '-ss',
          (at / 1000).toStringAsFixed(3),
          '-i',
          path,
          '-t',
          seconds,
          '-map',
          '0:${_info!.videoIndex}',
          '-an',
          '-sn',
          '-vf',
          'trim=duration=$seconds,fps=${6 / (span / 1000)},'
              'scale=96:96:force_original_aspect_ratio=increase,crop=96:96,tile=6x1',
        ], wave: true);
      });

  @override
  Future<String?> waveform(
    String path,
    Duration start,
    Duration length,
    String color,
  ) => _track(() async {
    if (_info?.audioIndex == null) return null;
    return _image([
      '-ss',
      (start.inMilliseconds / 1000).toStringAsFixed(3),
      '-t',
      (length.inMilliseconds.clamp(1, 30000) / 1000).toStringAsFixed(3),
      '-i',
      path,
      '-filter_complex',
      '[0:${_info!.audioIndex}]aformat=channel_layouts=mono,showwavespic=s=640x96:colors=0x$color[out]',
      '-map',
      '[out]',
      '-an',
      '-sn',
    ], wave: true);
  });

  @override
  Future<bool> play(String path, Duration start, Duration end) =>
      _track(() async {
        if (_info?.audioIndex == null || start >= end) return false;
        final revision = ++_revision;
        await _positionSubscription?.cancel();
        await _completionSubscription?.cancel();
        await _player?.dispose();
        if (_closed || revision != _revision) return false;
        final player = _player = AudioPlayer();
        {
          _positionSubscription = player.onPositionChanged.listen((position) {
            if (!_closed && revision == _revision) {
              _positions.add(_audioStart + position);
            }
          });
          _completionSubscription = player.onPlayerComplete.listen((_) {
            if (!_closed && revision == _revision) _completed.add(null);
          });
        }
        await player.release();
        await player.setReleaseMode(ReleaseMode.stop);
        final output = join(_directory!.path, 'audio.wav');
        final length = (end - start).inMilliseconds.clamp(1, 30000);
        await _encode([
          '-ss',
          (start.inMilliseconds / 1000).toStringAsFixed(3),
          '-i',
          path,
          '-map',
          '0:${_info!.audioIndex}',
          '-t',
          (length / 1000).toStringAsFixed(3),
          '-vn',
          '-sn',
          '-c:a',
          'pcm_s16le',
          '-ar',
          '48000',
          '-ac',
          '2',
          output,
        ]);
        if (_closed || revision != _revision) return false;
        _audioStart = start;
        _audioEnd = start + Duration(milliseconds: length);
        await player.play(DeviceFileSource(output));
        if (_closed || revision != _revision) {
          await player.pause();
          return false;
        }
        return true;
      });

  @override
  Future<void> pause() async {
    _revision++;
    await _player?.pause();
  }

  @override
  Future<void> close() => _closing ??= _shutdown();

  Future<void> _shutdown() async {
    _closed = true;
    _revision++;
    for (final id in _sessions.toList()) {
      await FFmpegKit.cancel(id);
    }
    await Future.wait(_operations.toList());
    await _positionSubscription?.cancel();
    await _completionSubscription?.cancel();
    await _player?.dispose();
    await _positions.close();
    await _completed.close();
    await _directory?.delete(recursive: true);
  }
}
