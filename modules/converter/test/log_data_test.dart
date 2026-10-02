import 'dart:io';

import 'package:converter/converter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final synchronous in [true, false]) {
    for (final operation in ['set', 'append', 'clear']) {
      test(
        '$operation observes log save errors, synchronous=$synchronous',
        () async {
          final logs = _FailingLogs(synchronous);
          switch (operation) {
            case 'set':
              logs.setLog('job', 'new');
            case 'append':
              logs.appendLog('job', 'new');
            case 'clear':
              logs.clearLog('job');
          }
          await Future<void>.delayed(Duration.zero);
          expect(logs.writes.single, (
            'job',
            switch (operation) {
              'set' => 'new',
              'append' => 'existing\nnew',
              _ => null,
            },
          ));
        },
      );
    }
  }
  test('append observes a closed log box read error', () async {
    final logs = _FailingLogs(true)..failRead = true;
    logs.appendLog('job', 'new');
    await Future<void>.delayed(Duration.zero);
    expect(logs.writes, isEmpty);
  });

  test('rapid appends keep every line and persist in order', () async {
    final directory = await Directory.systemTemp.createTemp('mcu-log-qa-');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    messenger.setMockMethodCallHandler(channel, (_) async => directory.path);
    final logs = LogData.create();
    try {
      await EasyBox.initialize(subDir: 'logs');
      await logs.init();
      logs.setLog('job', 'first');
      logs.appendLog('job', 'second');
      logs.appendLog('job', 'third');
      logs.appendLog('job', '');
      expect(logs.getLog('job'), 'first\nsecond\nthird');
      await logs.close();
      await logs.init();
      expect(logs.getLog('job'), 'first\nsecond\nthird');
      logs.clearLog('job');
      logs.appendLog('job', 'after clear');
      await logs.close();
      await logs.init();
      expect(logs.getLog('job'), 'after clear');
    } finally {
      await logs.close();
      messenger.setMockMethodCallHandler(channel, null);
      await directory.delete(recursive: true);
    }
  });

  test(
    'bulk log cleanup deletes only requested keys across reopening',
    () async {
      final directory = await Directory.systemTemp.createTemp('mcu-log-qa-');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      messenger.setMockMethodCallHandler(channel, (_) async => directory.path);
      final logs = LogData.create();
      try {
        await EasyBox.initialize(subDir: 'logs');
        await logs.init();
        await logs.put('completed', 'Finished output');
        await logs.put('failed', 'Failure details');
        await logs.put('pending', 'Queued input');
        await logs.put('recovery', 'Output needs a destination');
        await logs.clearLogs(['completed', 'failed', 'absent']);
        expect(logs.getLog('completed'), isEmpty);
        expect(logs.getLog('failed'), isEmpty);
        expect(logs.getLog('absent'), isEmpty);
        await logs.close();
        await logs.init();
        expect(logs.getLog('completed'), isEmpty);
        expect(logs.getLog('failed'), isEmpty);
        expect(logs.getLog('pending'), 'Queued input');
        expect(logs.getLog('recovery'), 'Output needs a destination');
        await logs.clearLogs([]);
        expect(logs.getLog('pending'), 'Queued input');
        expect(logs.getLog('recovery'), 'Output needs a destination');
      } finally {
        await logs.close();
        messenger.setMockMethodCallHandler(channel, null);
        await directory.delete(recursive: true);
      }
    },
  );
}

class _FailingLogs(final bool synchronous) implements LogData {
  final writes = <(dynamic, dynamic)>[];
  bool failRead = false;

  @override
  dynamic get(dynamic key, {required dynamic defaultValue}) {
    if (failRead) throw StateError('Log box closed');
    return 'existing';
  }

  @override
  Future<void> put(dynamic key, dynamic value) {
    writes.add((key, value));
    if (synchronous) throw StateError('Log box closed');
    return Future<void>.error(StateError('Log write failed'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
