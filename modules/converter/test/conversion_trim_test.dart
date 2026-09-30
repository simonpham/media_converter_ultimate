import 'package:converter/converter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('timestamps preserve milliseconds in seconds and clock formats', () {
    for (final (text, milliseconds) in [
      ('90', 90000),
      ('1.001', 1001),
      ('1,25', 1250),
      ('1:30.125', 90125),
      ('1:02:03.004', 3723004),
      (' 00:00 ', 0),
      ('123:45', 7425000),
    ]) {
      expect(
        MediaTimestamp.parse(text)?.inMilliseconds,
        milliseconds,
        reason: text,
      );
    }
  });

  test('invalid timestamps never become command arguments', () {
    for (final text in [
      '',
      '-1',
      'NaN',
      'Infinity',
      '1e3',
      '00:60',
      '1:60:00',
      '1:2:3:4',
      '1.2345',
      ':20',
      '20:',
      '1.2:30',
      '1: 20',
      '999999999999999999999999',
      '1; rm',
      '00:00.-1',
    ]) {
      expect(MediaTimestamp.parse(text), isNull, reason: text);
    }
  });

  test(
    'output trim emits precise seek and length rather than an end timestamp',
    () {
      const trim = ConversionTrim(
        start: Duration(milliseconds: 750),
        end: Duration(milliseconds: 1750),
      );
      expect(trim.arguments, ['-ss', '0.750', '-t', '1.000']);
      final restored = ConversionTrim.fromArguments([
        '-i',
        '-ss',
        ...trim.arguments,
        '-ss',
      ]);
      expect(restored?.start, trim.start);
      expect(restored?.end, trim.end);
    },
  );

  test('a start-only trim keeps the remaining media', () {
    const trim = ConversionTrim(start: Duration(seconds: 3));
    expect(trim.arguments, ['-ss', '3.000']);
    expect(trim.effectiveDuration(10000), 7000);
    expect(trim.effectiveDuration(2000), 0);
  });

  test(
    'trim duration is bounded by the source and handles unknown duration',
    () {
      const trim = ConversionTrim(
        start: Duration(seconds: 3),
        end: Duration(seconds: 12),
      );
      expect(trim.effectiveDuration(10000), 7000);
      expect(trim.effectiveDuration(20000), 9000);
      expect(trim.effectiveDuration(0), 9000);
      expect(
        const ConversionTrim(start: Duration(seconds: 3)).effectiveDuration(0),
        0,
      );
      expect(
        ConversionTrim.fromArguments(['-i', '/in.mp3', '/out.mp3']),
        isNull,
      );
    },
  );

  test('preview timestamps retain clock values and optional precision', () {
    expect(
      MediaTimestamp.display(const Duration(milliseconds: 750)),
      '00:00.750',
    );
    expect(
      MediaTimestamp.display(const Duration(minutes: 90, milliseconds: 1)),
      '1:30:00.001',
    );
    expect(MediaTimestamp.display(Duration.zero), '00:00');
  });
}
