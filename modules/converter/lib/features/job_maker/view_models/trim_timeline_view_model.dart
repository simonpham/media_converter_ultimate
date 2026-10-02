import 'dart:async';

import 'package:converter/converter.dart';
import 'package:flutter/foundation.dart';
import 'package:platform_utils/platform_utils.dart';

enum TrimTarget { start, cursor, end }

class TrimTimelineViewModel({
  required final String path,
  required final MediaPreviewSession session,
  required final String waveColor,
  final ConversionTrim? initial,
}) extends ChangeNotifier {
  PreviewMediaInfo? _info;
  TrimTarget _target = .cursor;
  TrimTarget get target => _target;
  String? _thumbnails;
  String? get thumbnails =>
      _stripStart == windowStart && _stripLength == windowLength
      ? _thumbnails
      : null;
  bool _stripBusy = false;
  bool _stripRequested = false;
  int? _stripStart;
  int? _stripLength;
  PreviewMediaInfo? get info => _info;
  int _start = 0;
  int _end = 1;
  int _position = 0;
  int _window = 1;
  int _windowStart = 0;
  bool _disposed = false;
  bool _loading = true;
  bool _playing = false;
  bool _preparingAudio = false;
  bool _frameBusy = false;
  bool _waveBusy = false;
  bool _frameRequested = false;
  bool _waveRequested = false;
  bool _failed = false;
  bool _imageFailed = false;
  String? _frame;
  String? _waveform;
  int? _waveStart;
  int? _waveLength;
  StreamSubscription<Duration>? _positions;
  StreamSubscription<void>? _completed;
  DateTime _lastFrameRequest = DateTime.fromMillisecondsSinceEpoch(0);

  bool get loading => _loading;
  bool get playing => _playing;
  bool get preparingAudio => _preparingAudio;
  bool get failed => _failed;
  bool get imageFailed => _imageFailed;
  String? get frame => _frame;
  String? get waveform =>
      _waveStart == windowStart && _waveLength == windowLength
      ? _waveform
      : null;
  int get duration => _info?.duration.inMilliseconds ?? 1;
  int get start => _start;
  int get end => _end;
  int get position => _position;
  int get windowLength => _window.clamp(1, duration);
  bool get isOverview => windowLength == duration;
  bool get canZoomIn => windowLength > duration.clamp(1, 100);
  bool get needsWaveformZoom =>
      _info?.videoIndex == null &&
      _info?.audioIndex != null &&
      windowLength > 30000;
  int get windowStart => _windowStart;
  int get windowEnd => windowStart + windowLength;
  ConversionTrim get result => ConversionTrim(
    start: Duration(milliseconds: _start),
    end: _end == duration ? null : Duration(milliseconds: _end),
  );

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize({PreviewMediaInfo? information}) async {
    try {
      _info = information ?? await session.inspect(path);
      if (_info!.duration <= Duration.zero) {
        throw StateError('Invalid duration');
      }
      if (_disposed) return;
      _start = (initial?.start.inMilliseconds ?? 0).clamp(0, duration - 1);
      _end = (initial?.end?.inMilliseconds ?? duration).clamp(
        _start + 1,
        duration,
      );
      _position = _start;
      _window = duration;
      _centerWindow();
      _positions = session.positions.listen((position) {
        if (!_playing || _disposed) return;
        _position = position.inMilliseconds.clamp(0, _end);
        if (_position < windowStart || _position > windowEnd) {
          _centerWindow();
          requestWaveform();
          requestThumbnails();
        }
        if (_position >= _end) unawaited(pause());
        final now = DateTime.now();
        if (now.difference(_lastFrameRequest).inMilliseconds >= 500) {
          _lastFrameRequest = now;
          requestFrame();
        }
        _notify();
      });
      _completed = session.completed.listen((_) {
        if (_disposed || !_playing) return;
        _playing = false;
        _position = session.audioEnd.inMilliseconds.clamp(0, _end);
        _centerWindow();
        requestFrame();
        requestWaveform();
        requestThumbnails();
        _notify();
      });
      requestFrame();
      requestWaveform();
      requestThumbnails();
    } catch (error, trace) {
      printError(error, trace);
      _failed = true;
    } finally {
      _loading = false;
      _notify();
    }
  }

  void setRange(int start, int end) {
    _start = start.clamp(0, duration - 1);
    _end = end.clamp(_start + 1, duration);
    unawaited(pause());
    _notify();
  }

  void setStartAtCursor() => setRange(_position.clamp(0, _end - 1), _end);
  void setEndAtCursor() =>
      setRange(_start, _position.clamp(_start + 1, duration));

  void seek(int milliseconds, {bool preview = true}) {
    unawaited(pause());
    _position = milliseconds.clamp(0, duration);
    if (_position < windowStart || _position > windowEnd) _centerWindow();
    if (preview) {
      requestFrame();
      requestWaveform();
      requestThumbnails();
    }
    _notify();
  }

  void selectTarget(TrimTarget target) {
    _target = target;
    seek(switch (target) {
      .start => _start,
      .cursor => _position,
      .end => _end,
    });
  }

  void adjustBoundary(
    TrimTarget target,
    int milliseconds, {
    bool preview = true,
  }) {
    _target = target;
    if (target == .start) {
      setRange(milliseconds.clamp(0, _end - 1), _end);
      seek(_start, preview: preview);
    } else if (target == .end) {
      setRange(_start, milliseconds.clamp(_start + 1, duration));
      seek(_end, preview: preview);
    } else {
      seek(milliseconds, preview: preview);
    }
  }

  void moveRange(int milliseconds, {bool preview = true}) {
    final length = _end - _start;
    final start = (_start + milliseconds).clamp(0, duration - length);
    final delta = start - _start;
    final position = (_position + delta).clamp(start, start + length);
    _target = .cursor;
    setRange(start, start + length);
    seek(position, preview: preview);
  }

  void nudge(int milliseconds) =>
      adjustBoundary(_target, _position + milliseconds);

  void panWindow(bool forward) {
    unawaited(pause());
    _windowStart =
        (_windowStart + (forward ? windowLength ~/ 2 : -windowLength ~/ 2))
            .clamp(0, duration - windowLength);
    _position = _position.clamp(windowStart, windowEnd);
    _target = .cursor;
    requestFrame();
    requestWaveform();
    requestThumbnails();
    _notify();
  }

  void zoom(bool inward) {
    _window = (inward ? windowLength ~/ 2 : windowLength * 2).clamp(
      duration.clamp(1, 100),
      duration,
    );
    _centerWindow();
    requestWaveform();
    requestThumbnails();
    _notify();
  }

  void fitTimeline() {
    unawaited(pause());
    _window = duration;
    _windowStart = 0;
    requestWaveform();
    requestThumbnails();
    _notify();
  }

  void _centerWindow() {
    _windowStart = (_position - windowLength ~/ 2).clamp(
      0,
      duration - windowLength,
    );
  }

  Future<void> pause() async {
    _playing = false;
    _notify();
    try {
      await session.pause();
    } catch (error, trace) {
      printError(error, trace);
    }
  }

  Future<void> play() async {
    if (_preparingAudio || _info?.audioIndex == null || _disposed) return;
    _preparingAudio = true;
    if (_position < _start || _position >= _end) _position = _start;
    _notify();
    try {
      final played = await session.play(
        path,
        Duration(milliseconds: _position),
        Duration(milliseconds: _end),
      );
      if (!_disposed) _playing = played;
    } catch (error, trace) {
      printError(error, trace);
      _imageFailed = true;
    } finally {
      _preparingAudio = false;
      _notify();
    }
  }

  void requestFrame() {
    if (_disposed || _info?.videoIndex == null) return;
    _frameRequested = true;
    if (!_frameBusy) {
      unawaited(_renderFrame());
    }
  }

  Future<void> _renderFrame() async {
    _frameBusy = true;
    try {
      while (_frameRequested && !_disposed) {
        _frameRequested = false;
        final position = _position;
        final image = await session.frame(
          path,
          Duration(milliseconds: position),
        );
        if (!_disposed && !_frameRequested) _frame = image;
        _notify();
      }
    } catch (error, trace) {
      printError(error, trace);
      _imageFailed = true;
      _notify();
    } finally {
      _frameBusy = false;
    }
  }

  void requestWaveform() {
    if (_disposed ||
        _info?.audioIndex == null ||
        _info?.videoIndex != null ||
        needsWaveformZoom) {
      return;
    }
    if (!_waveBusy &&
        _waveform != null &&
        _waveStart == windowStart &&
        _waveLength == windowLength) {
      return;
    }
    _waveRequested = true;
    if (!_waveBusy) unawaited(_renderWaveform());
  }

  Future<void> _renderWaveform() async {
    _waveBusy = true;
    try {
      while (_waveRequested && !_disposed && !needsWaveformZoom) {
        _waveRequested = false;
        // Waveform windows are bounded even when the full media is many hours.
        final length = windowLength.clamp(1, 30000);
        final start = windowStart;
        final image = await session.waveform(
          path,
          Duration(milliseconds: start),
          Duration(milliseconds: length),
          waveColor,
        );
        if (!_disposed && !_waveRequested) {
          _waveform = image;
          _waveStart = start;
          _waveLength = length;
        }
        _notify();
      }
    } catch (error, trace) {
      printError(error, trace);
      _imageFailed = true;
      _notify();
    } finally {
      _waveBusy = false;
    }
  }

  void requestThumbnails() {
    if (_disposed || _info?.videoIndex == null) return;
    if (!_stripBusy &&
        _thumbnails != null &&
        _stripStart == windowStart &&
        _stripLength == windowLength) {
      return;
    }
    _stripRequested = true;
    if (!_stripBusy) unawaited(_renderThumbnails());
  }

  Future<void> _renderThumbnails() async {
    _stripBusy = true;
    try {
      while (_stripRequested && !_disposed) {
        _stripRequested = false;
        final start = windowStart;
        final length = windowLength;
        final image = await session.thumbnails(
          path,
          Duration(milliseconds: start),
          Duration(milliseconds: length),
        );
        if (!_disposed && !_stripRequested) {
          _thumbnails = image;
          _stripStart = start;
          _stripLength = length;
        }
        _notify();
      }
    } catch (error, trace) {
      if (!_disposed) {
        printError(error, trace);
        _imageFailed = true;
        _notify();
      }
    } finally {
      _stripBusy = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    if (_positions != null) unawaited(_positions!.cancel());
    if (_completed != null) unawaited(_completed!.cancel());
    unawaited(
      session.close().catchError(
        (Object error, StackTrace trace) => printError(error, trace),
      ),
    );
    super.dispose();
  }
}
