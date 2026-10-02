import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:converter/converter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcu/theme_adapter.dart';
import 'package:platform_utils/platform_utils.dart'
    show DirectFileService, FileService;
import 'package:sofluffy_ui/sofluffy_ui.dart';

import 'support/conversion_test_support.dart';

void main() {
  late _Manager model;
  late _Files files;
  late FluffyThemeData theme;

  setUp(() {
    installShippedAssetHandler();
    files = _Files();
    injector.registerSingleton<SettingsBox>(MemorySettings());
    injector.registerSingleton<FileService>(files);
    injector.registerSingleton<JobRunnerService>(_Runner());
    model = _Manager();
    theme = FluffyThemeData.fromJson(
      jsonDecode(
        File('${findRepository().path}/apps/mcu/assets/themes/default.json')
            .readAsStringSync(),
      ),
    );
  });

  tearDown(() async {
    model.dispose();
    clearShippedAssetHandler();
    await injector.reset();
  });

  Future<void> showJobs(WidgetTester tester, ConvertJob job) async {
    model.job = job;
    await tester.pumpWidget(
      ChangeNotifierProvider<JobManagerViewModel>.value(
        value: model,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: theme.getTheme(isDark: false),
          builder: (context, child) => FluffyTheme(
            data: theme.getFluffyTheme(isDark: false),
            child: child!,
          ),
          home: const JobManager(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(job.outputFileName),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  for (final uri in <String?>[null, 'content://media/external/downloads/42']) {
    testWidgets(
      'completed output exposes Open and Share for ${uri ?? 'local files'}',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final job = _job(uri: uri);
          await showJobs(tester, job);
          await tester.ensureVisible(find.bySemanticsLabel('Open file'));
          await tester.tap(find.bySemanticsLabel('Open file'));
          await tester.pumpAndSettle();
          await tester.tap(find.bySemanticsLabel('Share file'));
          await tester.pumpAndSettle();
          expect(files.opened, [job.outputLocation]);
          expect(files.shared, [job.outputLocation]);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets(
    'unavailable output keeps history and explains Open and Share failures',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        files.exists = false;
        await showJobs(tester, _job());
        await tester.ensureVisible(find.bySemanticsLabel('Open file'));
        await tester.tap(find.bySemanticsLabel('Open file'));
        await tester.pump();
        expect(
          find.textContaining('This output is unavailable.'),
          findsOneWidget,
        );
        expect(files.opened, isEmpty);
        await tester.pump(const Duration(seconds: 5));
        await tester.tap(find.bySemanticsLabel('Share file'));
        await tester.pump();
        expect(
          find.textContaining('This output is unavailable.'),
          findsOneWidget,
        );
        expect(files.shared, isEmpty);
        expect(find.text('output.wav'), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('failed conversions do not expose output actions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await showJobs(tester, _job(status: .failed));
      expect(find.bySemanticsLabel('Open file'), findsNothing);
      expect(find.bySemanticsLabel('Share file'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  for (final action in ['Open file', 'Share file']) {
    testWidgets(
      '$action failure gives the correct message and retains history',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          files.failActions = true;
          await showJobs(tester, _job());
          await tester.ensureVisible(find.bySemanticsLabel(action));
          await tester.tap(find.bySemanticsLabel(action));
          await tester.pump();
          expect(
            find.textContaining(
              action == 'Open file'
                  ? 'Could not open this file.'
                  : 'Could not share this file.',
            ),
            findsOneWidget,
          );
          expect(find.text('output.wav'), findsOneWidget);
          await tester.pump(const Duration(seconds: 5));
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets(
    'restart commit failure is shown without an unhandled exception',
    (tester) async {
      model.restartError = const Failure('Cannot save retry');
      await showJobs(tester, _job(status: .failed));
      await tester.ensureVisible(find.text('Restart'));
      await tester.tap(find.text('Restart'));
      await tester.pump();
      expect(find.text('Unknown error. Please try again.'), findsOneWidget);
      expect(model.restartCount, 1);
      expect(find.text('output.wav'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed overwrite deletion stops restart and preserves history', (
    tester,
  ) async {
    model.previousOutputExists = true;
    model.deleteFailure = const FileDeleteFailure('/stored/exports/output.wav');
    await showJobs(tester, _job(status: .failed));
    await tester.ensureVisible(find.text('Restart'));
    await tester.tap(find.text('Restart'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Overwrite'));
    await tester.pumpAndSettle();
    expect(
      find.text('Failed to delete file at /stored/exports/output.wav.'),
      findsOneWidget,
    );
    expect(model.deleteCount, 1);
    expect(model.restartCount, 0);
    expect(find.text('output.wav'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'removal storage exception is shown and retains the history row',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        model.removeError = StateError('Cannot delete record');
        await showJobs(tester, _job());
        final remove = find.bySemanticsLabel('Remove from history');
        await tester.ensureVisible(remove);
        await tester.tap(remove);
        await tester.pump();
        expect(find.text('Unknown error. Please try again.'), findsOneWidget);
        expect(find.text('output.wav'), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'closing Home during restart preflight prevents a late dialog or retry',
    (tester) async {
      model.previousOutputExists = true;
      model.outputCheckGate = Completer<void>();
      await showJobs(tester, _job(status: .failed));
      await tester.ensureVisible(find.text('Restart'));
      await tester.tap(find.text('Restart'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      model.outputCheckGate!.complete();
      await tester.pumpAndSettle();
      expect(model.restartCount, 0);
      expect(model.deleteCount, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

ConvertJob _job({String? uri, JobStatus status = .completed}) => ConvertJob(
  id: 'output-actions',
  inputFilePath: '/source.wav',
  outputFileName: 'output.wav',
  outputExtension: 'wav',
  outputDirectoryPath: '/stored/exports',
  outputUri: uri,
  command: '[]',
  convertedFilePath: '/temporary/output.wav',
  status: status,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

class _Files extends DirectFileService {
  final opened = <String>[];
  final shared = <String>[];
  bool exists = true;
  bool failActions = false;
  @override
  Future<bool> isFileExist(String location) async => exists;
  @override
  Future<void> openOutput(String location) async {
    if (failActions) throw StateError('No compatible app');
    opened.add(location);
  }

  @override
  Future<void> shareOutput(String location) async {
    if (failActions) throw StateError('No compatible app');
    shared.add(location);
  }
}

class _Manager extends JobManagerViewModel {
  late ConvertJob job;
  bool previousOutputExists = false;
  Object? restartError;
  Object? removeError;
  Failure? deleteFailure;
  Completer<void>? outputCheckGate;
  int restartCount = 0;
  int deleteCount = 0;
  @override
  Future<bool> isOutputFileExists(ConvertJob job) async {
    await outputCheckGate?.future;
    return previousOutputExists;
  }

  @override
  Future<void> restartJob(ConvertJob job) async {
    restartCount++;
    if (restartError case final error?) throw error;
  }

  @override
  Future<Failure?> deleteOutputFile(ConvertJob job) async {
    deleteCount++;
    return deleteFailure;
  }

  @override
  Future<Failure?> removeJob(ConvertJob job) async {
    if (removeError case final error?) throw error;
    return null;
  }

  @override
  Stream<List<ConvertJob>> get completedJobsStream => Stream.value([job]);
  @override
  Stream<List<ConvertJob>> get pendingJobsStream => Stream.value([]);
  @override
  Stream<List<ConvertJob>> get runningJobsStream => Stream.value([]);
  @override
  Stream<List<ConvertJob>> get actionRequiredJobsStream => Stream.value([]);
}

class _Runner implements JobRunnerService {
  @override
  Stream<ConvertJob> get onJobUpdate => const Stream.empty();
  @override
  Stream<JobLog> get onLogUpdate => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
