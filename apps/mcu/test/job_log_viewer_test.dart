import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:converter/converter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcu/theme_adapter.dart';
import 'package:platform_utils/platform_utils.dart'
    show DirectFileService, FileService;
import 'package:sofluffy_ui/sofluffy_ui.dart';

import 'support/conversion_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Logs logs;
  late JobLogViewModel model;
  late Directory directory;
  late _Files files;
  late ConvertJob job;
  String? clipboard;

  setUp(() async {
    logs = _Logs();
    injector.registerSingleton<LogData>(logs);
    directory = await Directory.systemTemp.createTemp('log-tools-test-');
    files = _Files(directory);
    injector.registerSingleton<FileService>(files);
    job = ConvertJob(
      id: 'log-test',
      inputFilePath: '/source.wav',
      outputFileName: '音楽 Việt.m4a',
      outputExtension: 'm4a',
      outputDirectoryPath: '/output',
      command: '[]',
      convertedFilePath: '/temp/output.m4a',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    logs.setLog(job.id, 'Start\nERROR: unsupported codec\nFinished Việt');
    model = JobLogViewModel(job)..initialize();
    clipboard = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = call.arguments['text'] as String;
          }
          return null;
        });
  });

  tearDown(() async {
    model.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    await injector.reset();
    logs.changes.dispose();
    await directory.delete(recursive: true);
  });

  test('search ignores case and whitespace and refreshes live log lines', () {
    model.setQuery('  error  ');
    expect(model.visibleLogs, 'ERROR: unsupported codec');
    logs.appendLog(job.id, 'New Error Việt');
    expect(model.visibleLogs, 'ERROR: unsupported codec\nNew Error Việt');
    model.setQuery('nothing');
    expect(model.visibleLogs, isEmpty);
    model.setQuery('');
    expect(model.visibleLogs, logs.getLog(job.id));
  });

  test(
    'long searches stay current after query changes, append and log replacement',
    () async {
      final lines = List.generate(
        10000,
        (index) => index % 1000 == 0
            ? 'ERROR [$index]: Codec Việt 音楽'
            : 'frame=$index fps=60 time=00:02:03.45 speed=1.5x',
      );
      logs.setLog(job.id, lines.join('\n'));
      model.setQuery('  error [  ');
      final matches = lines
          .where((line) => line.startsWith('ERROR'))
          .join('\n');
      expect(model.visibleLogs, matches);
      model.setQuery('ERROR [');
      expect(model.query, 'ERROR [');
      expect(model.visibleLogs, matches);
      logs.appendLog(job.id, 'ERROR [later]: interrupted export');
      expect(model.visibleLogs, '$matches\nERROR [later]: interrupted export');
      model.setQuery('Việt');
      expect(model.visibleLogs, matches);
      logs.setLog(job.id, 'Replacement log\nCodec Việt');
      expect(model.visibleLogs, 'Codec Việt');
      model.setQuery('replacement');
      expect(model.visibleLogs, 'Replacement log');
      await model.copyLogs();
      expect(clipboard, 'Replacement log\nCodec Việt');
      logs.clearLog(job.id);
      expect(model.visibleLogs, isEmpty);
      model.setQuery('   ');
      expect(model.visibleLogs, isEmpty);
      logs.appendLog(job.id, 'New attempt');
      expect(model.visibleLogs, 'New attempt');
    },
  );

  test(
    'copy retains complete diagnostic context when search filters lines',
    () async {
      model.setQuery('error');
      await model.copyLogs();
      expect(clipboard, logs.getLog(job.id));
    },
  );

  test(
    'export keeps a full UTF-8 snapshot and cleans its owned staging folder',
    () async {
      model.setQuery('error');
      files.pickGate = Completer<void>();
      final snapshot = model.logs;
      final exporting = model.exportLogs(null);
      expect(model.isExporting, isTrue);
      await model.exportLogs(null);
      expect(files.pickCount, 1);
      logs.appendLog(job.id, 'A later update');
      files.pickGate!.complete();
      final (path, failure) = await exporting;
      expect(failure, isNull);
      expect(path, endsWith('音楽 Việt.m4a.log.txt'));
      expect(await File(path!).readAsString(), snapshot);
      expect(await files.cache.list().toList(), isEmpty);
      expect(model.isExporting, isFalse);
    },
  );

  test(
    'export collision preserves the previous file and allows retry',
    () async {
      final output = File('${files.destination}/音楽 Việt.m4a.log.txt');
      await output.writeAsString('Existing log');
      final (path, failure) = await model.exportLogs(null);
      expect(path, isNull);
      expect(failure, isA<OutputFileAlreadyExistsFailure>());
      expect(await output.readAsString(), 'Existing log');
      expect(await files.cache.list().toList(), isEmpty);
      expect(model.isExporting, isFalse);
      await output.delete();
      expect((await model.exportLogs(null)).$2, isNull);
    },
  );

  test(
    'cancelled picker creates no staging file and leaves logs intact',
    () async {
      files.destination = null;
      expect(await model.exportLogs(null), (null, null));
      expect(await files.cache.list().toList(), isEmpty);
      expect(model.logs, logs.getLog(job.id));
    },
  );

  testWidgets('viewer searches live text and uses full-log menu actions', (
    tester,
  ) async {
    final theme = FluffyThemeData.fromJson(
      jsonDecode(
        File('${findRepository().path}/apps/mcu/assets/themes/default.json')
            .readAsStringSync(),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: theme.getTheme(isDark: false),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => FluffyTheme(
          data: theme.getFluffyTheme(isDark: false),
          child: child!,
        ),
        home: JobLogViewer(job: job),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Copy full log'), findsNothing);
    expect(find.text('Export full log'), findsNothing);
    final actions = find.byKey(const ValueKey('log-actions'));
    final search = find.descendant(
      of: find.byType(InputText),
      matching: find.byType(EditableText),
    );
    await tester.enterText(search, 'error');
    await tester.pumpAndSettle();
    expect(find.text('ERROR: unsupported codec'), findsOneWidget);
    logs.appendLog(job.id, 'New error line');
    await tester.pumpAndSettle();
    expect(
      find.text('ERROR: unsupported codec\nNew error line'),
      findsOneWidget,
    );
    await tester.tap(actions);
    await tester.pumpAndSettle();
    expect(find.text('Copy full log'), findsOneWidget);
    expect(find.text('Export full log'), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.tap(find.text('Copy full log'));
    await tester.pump(const Duration(seconds: 4));
    expect(clipboard, logs.getLog(job.id));
    expect(find.text('Copy full log'), findsNothing);
    await tester.tap(actions);
    await tester.pumpAndSettle();
    final exported = File('${files.destination}/音楽 Việt.m4a.log.txt');
    final viewerModel = tester
        .element(find.byType(SelectableText))
        .read<JobLogViewModel>();
    final exportedText = await tester.runAsync(() async {
      await tester.tap(find.text('Export full log'));
      for (
        var attempt = 0;
        viewerModel.isExporting && attempt < 100;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(viewerModel.isExporting, isFalse);
      return exported.readAsString();
    });
    await tester.pump(const Duration(seconds: 4));
    expect(files.pickCount, 1);
    expect(find.text('Export full log'), findsNothing);
    expect(exportedText, logs.getLog(job.id));
    await tester.enterText(search, 'no match');
    await tester.pumpAndSettle();
    expect(find.text('No matching log lines.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}

class _Changes extends ChangeNotifier implements ValueListenable<void> {
  @override
  void get value {}
  void changed() => notifyListeners();
}

class _Logs implements LogData {
  final values = <dynamic, dynamic>{};
  final changes = _Changes();
  @override
  dynamic get(dynamic key, {required dynamic defaultValue}) =>
      values[key] ?? defaultValue;
  @override
  Future<void> put(dynamic key, dynamic value) async {
    values[key] = value;
    changes.changed();
  }

  @override
  ValueListenable<void> listenTo<T>(List<T> keys) => changes;
  @override
  Future<void> onDispose() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Files(final Directory directory) extends DirectFileService {
  late final Directory cache = Directory('${directory.path}/cache')
    ..createSync();
  late String? destination = (Directory(
    '${directory.path}/export',
  )..createSync()).path;
  Completer<void>? pickGate;
  int pickCount = 0;
  @override
  Future<Directory> getAppCacheDirectory() async => cache;
  @override
  Future<(String?, Failure?)> chooseSavePath(
    dynamic context, {
    String? initialPath,
  }) async {
    pickCount++;
    await pickGate?.future;
    return (destination, null);
  }
}
