import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:core/core.dart';
import 'package:platform_utils/platform_utils.dart';
import 'package:platform_utils/services/waveform_envelope.dart';

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
  final _waveforms = <(int, int, String), String>{};
  final _pendingWaveforms = <(int, int, String), Future<String?>>{};
  int _audioSampleRate = 48000;
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
    _audioSampleRate =
        int.tryParse('${preferred?['sample_rate']}')?.clamp(1, 768000) ?? 48000;
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
        final span = length.inMilliseconds.clamp(
          1,
          _info!.duration.inMilliseconds - at,
        );
        if (span > 30000) return _overviewThumbnails(path, at, span);
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

  /// Seek to six points instead of decoding the entire long-video window.
  /// Samples are rendered sequentially to keep only one source decoder active.
  Future<String?> _overviewThumbnails(String path, int start, int span) async {
    final samples = <String>[];
    try {
      for (var index = 0; index < 6; index++) {
        if (_closed) throw StateError('Preview is closed');
        final sample = _newPath('png');
        samples.add(sample);
        final at = (start + span * (index + 0.5) / 6).round().clamp(
          0,
          _info!.duration.inMilliseconds - 1,
        );
        Future<void> render(int position) => _encode([
          '-ss',
          (position / 1000).toStringAsFixed(3),
          '-i',
          path,
          '-map',
          '0:${_info!.videoIndex}',
          '-an',
          '-sn',
          '-vf',
          'scale=96:96:force_original_aspect_ratio=increase,crop=96:96',
          '-frames:v',
          '1',
          '-update',
          '1',
          sample,
        ]);
        await render(at);
        if (!await File(sample).exists()) {
          await render((at - 1000).clamp(0, at));
        }
        if (!await File(sample).exists()) return null;
      }
      return await _image([
        for (final sample in samples) ...['-i', sample],
        '-filter_complex_threads',
        '1',
        '-filter_complex',
        'hstack=inputs=6[out]',
        '-map',
        '[out]',
        '-an',
        '-sn',
      ], wave: true);
    } finally {
      for (final sample in samples) {
        final file = File(sample);
        if (await file.exists()) await file.delete();
      }
    }
  }

  @override
  Future<String?> waveform(
    String path,
    Duration start,
    Duration length,
    String color,
  ) => _track(() async {
    if (_info?.audioIndex == null) return null;
    final duration = _info!.duration.inMilliseconds;
    final at = start.inMilliseconds.clamp(0, duration - 1);
    final span = length.inMilliseconds.clamp(1, duration - at);
    final key = (at, span, color);
    final cached = _waveforms.remove(key);
    if (cached != null && await File(cached).exists()) {
      _waveforms[key] = cached;
      return cached;
    }
    final pending = _pendingWaveforms[key];
    if (pending != null) return pending;
    final rendering = _renderWaveform(path, at, span, color);
    _pendingWaveforms[key] = rendering;
    try {
      final image = await rendering;
      if (image != null && !_closed) {
        _waveforms[key] = image;
        // Keep the full-file overview when evicting older detailed windows.
        while (_waveforms.length > 4) {
          final oldest = _waveforms.keys.firstWhere(
            (candidate) => candidate != (0, duration, color),
            orElse: () => _waveforms.keys.first,
          );
          await File(_waveforms.remove(oldest)!).delete();
        }
      }
      return image;
    } finally {
      final _ = _pendingWaveforms.remove(key);
    }
  });

  Future<String?> _renderWaveform(
    String path,
    int start,
    int span,
    String color,
  ) async {
    const width = 640;
    const height = 96;
    final metadata = File(_newPath('txt'));
    // Fixed-size audio frames cap working memory regardless of file duration.
    final samples = (_audioSampleRate * span / 1000 / width).ceil().clamp(
      32,
      16384,
    );
    try {
      await _encode([
        '-ss',
        (start / 1000).toStringAsFixed(3),
        '-i',
        path,
        '-map',
        '0:${_info!.audioIndex}',
        '-t',
        (span / 1000).toStringAsFixed(3),
        '-af',
        'atrim=duration=${(span / 1000).toStringAsFixed(3)},'
            'aformat=sample_fmts=fltp,asetpts=PTS-STARTPTS,'
            'asetnsamples=n=$samples:p=1,'
            'astats=metadata=1:reset=1:measure_perchannel=none:measure_overall=Peak_level,'
            'ametadata=mode=print:key=lavfi.astats.Overall.Peak_level:file=${escapeFilterValue(metadata.path)}',
        '-vn',
        '-sn',
        '-f',
        'null',
        '-',
      ]);
      if (_closed) return null;
      final envelope = WaveformEnvelope(
        length: Duration(milliseconds: span),
        frameLength: Duration(
          microseconds:
              (samples / _audioSampleRate * Duration.microsecondsPerSecond)
                  .ceil(),
        ),
        bins: width,
      );
      await for (final line
          in metadata
              .openRead()
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (_closed) return null;
        envelope.addLine(line);
      }
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final tint = ui.Color(0xff000000 | int.parse(color, radix: 16));
      final paint = ui.Paint()..color = tint;
      const center = height / 2;
      canvas.drawLine(
        const ui.Offset(0, height / 2),
        ui.Offset(width.toDouble(), height / 2),
        ui.Paint()
          ..color = tint.withValues(alpha: 0.3)
          ..strokeWidth = 1,
      );
      for (var index = 0; index < width; index++) {
        final extent = math.sqrt(envelope.peaks[index]) * (center - 2);
        if (extent > 0) {
          canvas.drawRect(
            ui.Rect.fromLTRB(
              index.toDouble(),
              center - extent,
              index + 1.0,
              center + extent,
            ),
            paint,
          );
        }
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(width, height);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        if (data == null || _closed) return null;
        final output = _newPath('png');
        await File(output).writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        return output;
      } finally {
        image.dispose();
        picture.dispose();
      }
    } finally {
      if (await metadata.exists()) await metadata.delete();
    }
  }

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
