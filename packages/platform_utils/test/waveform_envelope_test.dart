import 'package:flutter_test/flutter_test.dart';
import 'package:platform_utils/services/waveform_envelope.dart';

void main() {
  late WaveformEnvelope envelope;
  setUp(() {
    envelope = WaveformEnvelope(
      length: const Duration(seconds: 90),
      frameLength: const Duration(milliseconds: 100),
      bins: 90,
    );
  });

  void frame(String time, String peak) {
    envelope.addLine('frame:0 pts:0 pts_time:$time');
    envelope.addLine('lavfi.astats.Overall.Peak_level=$peak');
  }

  test('full overview retains quiet opening and loud sound near the end', () {
    frame('2.2', '-40');
    frame('45', '-inf');
    frame('88.5', '0');
    expect(envelope.peaks[2], closeTo(0.01, 0.000001));
    expect(envelope.peaks[45], 0);
    expect(envelope.peaks[88], 1);
    expect(envelope.peaks.where((peak) => peak > 0).length, 2);
  });

  test('a narrow transient wins over quieter frames within the same bin', () {
    frame('60.1', '-40');
    frame('60.2', '-6.0206');
    frame('60.3', '-inf');
    expect(envelope.peaks[60], closeTo(0.5, 0.000001));
    expect(envelope.peaks[59], 0);
    expect(envelope.peaks[61], 0);
  });

  test('frame boundaries cover adjacent bins and clamp at the file end', () {
    frame('4.95', '0');
    frame('89.95', '-6.0206');
    expect(envelope.peaks[4], 1);
    expect(envelope.peaks[5], 1);
    expect(envelope.peaks[89], closeTo(0.5, 0.000001));
    expect(envelope.peaks[88], 0);
    frame('90', '0');
    expect(envelope.peaks[89], closeTo(0.5, 0.000001));
  });

  test('invalid and nonfinite metadata cannot create spurious peaks', () {
    envelope.addLine('lavfi.astats.Overall.Peak_level=0');
    for (final time in ['NaN', 'Infinity', '-1', 'invalid', '91']) {
      frame(time, '0');
    }
    for (final peak in ['NaN', 'Infinity', 'inf', 'invalid']) {
      frame('1', peak);
    }
    frame('2', '-inf');
    expect(envelope.peaks, everyElement(0));
  });
}
