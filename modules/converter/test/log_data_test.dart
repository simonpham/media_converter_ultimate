import 'dart:io';

import 'package:converter/converter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
