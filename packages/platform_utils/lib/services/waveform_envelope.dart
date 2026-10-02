import 'dart:math' as math;
import 'dart:typed_data';

/// Reduces a streamed sequence of frame peaks to a fixed number of time bins.
/// Every frame contributes; silence and quiet channels are never sampled away.
class WaveformEnvelope({
  required final Duration length,
  required final Duration frameLength,
  final int bins = 640,
}) {
  static final _timestamp = RegExp(r'pts_time:([^\s]+)');
  static const _peakKey = 'lavfi.astats.Overall.Peak_level=';
  late final Float64List peaks = Float64List(bins);
  double? _time;

  void addLine(String line) {
    if (line.startsWith('frame:')) {
      _time = double.tryParse(_timestamp.firstMatch(line)?.group(1) ?? '');
      return;
    }
    final time = _time;
    if (time == null ||
        !time.isFinite ||
        time < 0 ||
        !line.startsWith(_peakKey)) {
      return;
    }
    final value = line.substring(_peakKey.length).trim();
    final decibels = value == '-inf'
        ? double.negativeInfinity
        : double.tryParse(value);
    if (decibels == null || decibels.isNaN || decibels == double.infinity) {
      return;
    }
    final seconds = length.inMicroseconds / Duration.microsecondsPerSecond;
    if (seconds <= 0 || time >= seconds) return;
    final peak = decibels == double.negativeInfinity
        ? 0.0
        : math.pow(10, decibels / 20).toDouble().clamp(0.0, 1.0);
    final scale = bins / seconds;
    final first = (time * scale).floor().clamp(0, bins - 1);
    final last =
        ((time + frameLength.inMicroseconds / Duration.microsecondsPerSecond) *
                scale)
            .ceil()
            .clamp(first + 1, bins);
    for (var index = first; index < last; index++) {
      peaks[index] = math.max(peaks[index], peak);
    }
  }
}

/// Escape both AVOption delimiters and the surrounding filtergraph syntax.
String escapeFilterValue(String value) {
  String escape(String text, String characters) => text
      .split('')
      .map(
        (character) =>
            characters.contains(character) ? '\\$character' : character,
      )
      .join();
  return escape(escape(value, "\\':"), "\\'[],;");
}
