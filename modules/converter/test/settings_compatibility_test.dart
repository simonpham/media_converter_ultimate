import 'dart:io';

import 'package:converter/converter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_utils/platform_utils.dart' show OutputDestination;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StoredSettings settings;

  setUp(() => settings = StoredSettings());

  test(
    'valid saved preferences retain their values without being rewritten',
    () {
      final folder = OutputDestination.tree(
        'content://provider/tree/music',
        'Music',
      );
      settings.values.addAll({
        CoreSettings.language: 'vi',
        CoreSettings.lastKnownVersion: '1.0.7+100013',
        CoreSettings.appTheme: 'dark',
        JobMakerSettings.defaultOutputFormat: 'mp3',
        JobMakerSettings.lastOutputDirectoryPath: folder,
        JobMakerSettings.excludedFileExtensions: ['jpg', 'pdf'],
        JobMakerSettings.shouldExcludeNonMediaFiles: false,
        JobRunnerSettings.keepAppRunning: true,
        JobRunnerSettings.concurrencyLimit: 3,
        JobRunnerSettings.threadCount: 8,
        AdsSettings.appLaunchCount: 10,
      });
      expect(settings.language, 'vi');
      expect(settings.lastKnownVersion, '1.0.7+100013');
      expect(settings.appTheme, ThemeMode.dark);
      expect(settings.defaultOutputFormat, 'mp3');
      expect(settings.lastOutputDirectoryPath, folder);
      expect(settings.excludedFileExtensions, ['jpg', 'pdf']);
      expect(settings.shouldExcludeNonMediaFiles, isFalse);
      expect(settings.keepAppRunning, isTrue);
      expect(settings.concurrencyLimit, 3);
      expect(settings.threadCount, 8);
      expect(settings.appLaunchCount, 10);
      expect(settings.writes, isEmpty);
    },
  );

  test('malformed settings cannot crash startup or conversion setup', () {
    settings.values.addAll({
      CoreSettings.language: 42,
      CoreSettings.lastKnownVersion: ['old'],
      CoreSettings.appTheme: {},
      JobMakerSettings.defaultOutputFormat: 42,
      JobMakerSettings.lastOutputDirectoryPath: false,
      JobMakerSettings.shouldExcludeNonMediaFiles: 'false',
      JobRunnerSettings.keepAppRunning: 'true',
      JobRunnerSettings.concurrencyLimit: 'three',
      JobRunnerSettings.threadCount: 'many',
      AdsSettings.appLaunchCount: 'many',
      AdsSettings.filePickerAccessCount: {},
      AdsSettings.outputFormatPickerAccessCount: false,
      AdsSettings.successConversionCount: -1,
    });
    expect(settings.language, isIn(kSupportedLanguages.keys));
    expect(settings.lastKnownVersion, isEmpty);
    expect(settings.appTheme, ThemeMode.system);
    expect(settings.defaultOutputFormat, isNull);
    expect(settings.lastOutputDirectoryPath, isNull);
    expect(settings.shouldExcludeNonMediaFiles, isTrue);
    expect(settings.keepAppRunning, isFalse);
    expect(settings.concurrencyLimit, 1);
    expect(settings.threadCount, 0);
    expect(settings.appLaunchCount, 0);
    expect(settings.filePickerAccessCount, 0);
    expect(settings.outputFormatPickerAccessCount, 0);
    expect(settings.successConversionCount, 0);
    expect(settings.writes, isEmpty);
  });

  test('invalid execution limits stay within the supported settings range', () {
    settings.values[JobRunnerSettings.concurrencyLimit] = 0;
    settings.values[JobRunnerSettings.threadCount] = -1;
    expect(settings.concurrencyLimit, 1);
    expect(settings.threadCount, 0);
    settings.values[JobRunnerSettings.concurrencyLimit] = 100;
    settings.values[JobRunnerSettings.threadCount] = 100;
    expect(settings.concurrencyLimit, 4);
    expect(settings.threadCount, 16);
    expect(settings.writes, isEmpty);
  });

  test('mixed extension lists keep valid custom exclusions without changing storage', () {
    final raw = [
      'pdf',
      42,
      'jpg',
      null,
      {'old': true},
    ];
    settings.values[JobMakerSettings.excludedFileExtensions] = raw;
    expect(settings.excludedFileExtensions, ['pdf', 'jpg']);
    expect(settings.values[JobMakerSettings.excludedFileExtensions], same(raw));
    expect(settings.writes, isEmpty);
  });

  test('unreadable exclusions fall back without erasing the saved value', () {
    settings.values[JobMakerSettings.excludedFileExtensions] = 'old-data';
    expect(settings.excludedFileExtensions, kDefaultExcludedFileExtensions);
    expect(
      settings.values[JobMakerSettings.excludedFileExtensions],
      'old-data',
    );
    expect(settings.writes, isEmpty);
    settings.values[JobMakerSettings.excludedFileExtensions] = <String>[];
    expect(settings.excludedFileExtensions, isEmpty);
  });

  test(
    'disk-backed preferences survive recovery reads and reopening',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'mcu-settings-qa-',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      messenger.setMockMethodCallHandler(channel, (_) async => directory.path);
      final box = SettingsBox.create();
      try {
        await EasyBox.initialize(subDir: 'preferences');
        await box.init();
        await box.put(CoreSettings.language, 'vi');
        await box.put(
          JobMakerSettings.lastOutputDirectoryPath,
          '/custom/Music',
        );
        await box.put(JobRunnerSettings.threadCount, 8);
        await box.put(JobRunnerSettings.concurrencyLimit, 0);
        await box.put(JobMakerSettings.excludedFileExtensions, ['pdf', 42]);
        expect(box.concurrencyLimit, 1);
        expect(box.excludedFileExtensions, ['pdf']);
        await box.close();
        await box.init();
        expect(box.language, 'vi');
        expect(box.lastOutputDirectoryPath, '/custom/Music');
        expect(box.threadCount, 8);
        expect(box.concurrencyLimit, 1);
        expect(box.excludedFileExtensions, ['pdf']);
        expect(
          box.get(JobRunnerSettings.concurrencyLimit, defaultValue: null),
          0,
        );
        expect(
          box.get(JobMakerSettings.excludedFileExtensions, defaultValue: null),
          ['pdf', 42],
        );
      } finally {
        await box.close();
        messenger.setMockMethodCallHandler(channel, null);
        await directory.delete(recursive: true);
      }
    },
  );
}

class StoredSettings implements SettingsBox {
  final values = <Object, Object?>{};
  final writes = <Object>[];

  @override
  dynamic get(dynamic key, {required dynamic defaultValue}) =>
      values.containsKey(key) ? values[key] : defaultValue;

  @override
  Future<void> put(dynamic key, dynamic value) async {
    values[key] = value;
    writes.add(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
