import 'package:flutter/foundation.dart';

/// A non-null navigation result distinguishes Apply full file from Cancel.
@immutable
class const FileTrimResult({
  required final Duration duration,
  final ConversionTrim? trim,
});

/// Exact millisecond timestamps for the optional output trim range.
abstract final class MediaTimestamp {
  static Duration? parse(String text) {
    final parts = text.trim().replaceAll(',', '.').split(':');
    if (parts.isEmpty || parts.length > 3) return null;
    if (parts.any((part) => part.isEmpty)) return null;
    final secondsText = parts.last;
    if (!RegExp(r'^\d{1,9}(\.\d{1,3})?$').hasMatch(secondsText)) return null;
    final secondsParts = secondsText.split('.');
    final seconds = int.parse(secondsParts.first);
    if (parts.length > 1 && seconds >= 60) return null;
    final milliseconds = secondsParts.length == 1
        ? 0
        : int.parse(secondsParts.last.padRight(3, '0'));
    var total = seconds * 1000 + milliseconds;
    if (parts.length > 1) {
      final minutesText = parts[parts.length - 2];
      if (!RegExp(r'^\d{1,9}$').hasMatch(minutesText)) return null;
      final minutes = int.parse(minutesText);
      if (parts.length == 3 && minutes >= 60) return null;
      total += minutes * Duration.millisecondsPerMinute;
    }
    if (parts.length == 3) {
      if (!RegExp(r'^\d{1,6}$').hasMatch(parts.first)) return null;
      total += int.parse(parts.first) * Duration.millisecondsPerHour;
    }
    return Duration(milliseconds: total);
  }

  static String seconds(Duration value) =>
      '${value.inMilliseconds ~/ 1000}.${(value.inMilliseconds % 1000).toString().padLeft(3, '0')}';

  static String display(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    final milliseconds = value.inMilliseconds.remainder(1000);
    return '${hours > 0 ? '$hours:' : ''}$minutes:$seconds'
        '${milliseconds > 0 ? '.${milliseconds.toString().padLeft(3, '0')}' : ''}';
  }
}

@immutable
class const ConversionTrim({
  final Duration start = Duration.zero,
  final Duration? end,
}) {
  List<String> get inputArguments => [
    if (start > Duration.zero) ...['-ss', MediaTimestamp.seconds(start)],
  ];

  List<String> get outputArguments => [
    if (end case final end?) ...['-t', MediaTimestamp.seconds(end - start)],
  ];

  List<String> get arguments => [...inputArguments, ...outputArguments];

  int effectiveDuration(int sourceDurationMilliseconds) {
    final endMilliseconds = end?.inMilliseconds;
    final actualEnd = sourceDurationMilliseconds > 0
        ? endMilliseconds == null ||
                  endMilliseconds > sourceDurationMilliseconds
              ? sourceDurationMilliseconds
              : endMilliseconds
        : endMilliseconds ?? start.inMilliseconds;
    return (actualEnd - start.inMilliseconds).clamp(0, actualEnd);
  }

  /// Reads the generated output options while excluding input/output paths.
  static ConversionTrim? fromArguments(List<String> arguments) {
    Duration? start;
    Duration? length;
    for (var index = 0; index < arguments.length - 1; index++) {
      final argument = arguments[index];
      if (argument == '-i') {
        index++;
        continue;
      }
      if (argument != '-ss' && argument != '-t') continue;
      final value = MediaTimestamp.parse(arguments[++index]);
      if (value == null) return null;
      if (argument == '-ss') {
        start = value;
      } else {
        length = value;
      }
    }
    if (start == null && length == null) return null;
    final actualStart = start ?? Duration.zero;
    return .new(
      start: actualStart,
      end: length == null ? null : actualStart + length,
    );
  }
}
