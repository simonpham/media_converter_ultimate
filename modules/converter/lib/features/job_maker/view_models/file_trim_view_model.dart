import 'dart:async';

import 'package:converter/converter.dart';
import 'package:flutter/foundation.dart';
import 'package:platform_utils/platform_utils.dart';

/// A draft for one source. Only the editor's Apply action commits it.
class FileTrimViewModel({
  required final String path,
  required final MediaPreviewSession session,
  final ConversionTrim? initial,
}) extends ChangeNotifier {
  Duration? _duration;
  PreviewMediaInfo? _info;
  PreviewMediaInfo? get info => _info;
  Duration? get duration => _duration;
  bool _loading = true;
  bool get loading => _loading;
  bool _failed = false;
  bool get failed => _failed;
  bool _disposed = false;
  String _startText = '';
  String get startText => _startText;
  String _endText = '';
  String get endText => _endText;

  Future<void> initialize() async {
    _startText = initial == null ? '' : MediaTimestamp.display(initial!.start);
    _endText = initial?.end == null
        ? ''
        : MediaTimestamp.display(initial!.end!);
    try {
      final info = await session.inspect(path);
      if (_disposed) return;
      if (info.duration <= Duration.zero) throw StateError('Invalid duration');
      _info = info;
      _duration = info.duration;
    } catch (error, trace) {
      if (_disposed) return;
      printError(error, trace);
      _failed = true;
    } finally {
      _loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  void setStartText(String text) {
    _startText = text;
    notifyListeners();
  }

  void setEndText(String text) {
    _endText = text;
    notifyListeners();
  }

  void setRange(ConversionTrim range) {
    _startText = MediaTimestamp.display(range.start);
    _endText = range.end == null ? '' : MediaTimestamp.display(range.end!);
    notifyListeners();
  }

  void reset() {
    _startText = '';
    _endText = '';
    notifyListeners();
  }

  Failure? get startFailure =>
      _startText.trim().isNotEmpty && MediaTimestamp.parse(_startText) == null
      ? const InvalidTrimTimestampFailure()
      : null;
  Failure? get endFailure =>
      _endText.trim().isNotEmpty && MediaTimestamp.parse(_endText) == null
      ? const InvalidTrimTimestampFailure()
      : null;

  Failure? get rangeFailure {
    if (startFailure != null || endFailure != null) return null;
    final start = MediaTimestamp.parse(_startText) ?? Duration.zero;
    final end = MediaTimestamp.parse(_endText);
    if (end != null && end <= start) return const InvalidTrimRangeFailure();
    if (_duration case final duration?) {
      if (start >= duration || (end != null && end > duration)) {
        return const InvalidTrimBoundsFailure();
      }
    }
    return null;
  }

  bool get canApply =>
      !_loading &&
      !_failed &&
      _duration != null &&
      startFailure == null &&
      endFailure == null &&
      rangeFailure == null;

  ConversionTrim? get range {
    if (!canApply) return null;
    final start = MediaTimestamp.parse(_startText) ?? Duration.zero;
    final end = MediaTimestamp.parse(_endText);
    if (start == Duration.zero && (end == null || end == _duration)) {
      return null;
    }
    return ConversionTrim(start: start, end: end == _duration ? null : end);
  }

  FileTrimResult get result {
    if (!canApply) throw StateError('Cannot apply an invalid trim draft');
    return FileTrimResult(duration: _duration!, trim: range);
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(
      session.close().catchError((Object error, StackTrace trace) {
        printError(error, trace);
      }),
    );
    super.dispose();
  }
}
