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
  late ValueNotifier<bool> homeVisible;

  setUp(() {
    installShippedAssetHandler();
    files = _Files();
    homeVisible = ValueNotifier(true);
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
    homeVisible.dispose();
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
          home: ValueListenableBuilder<bool>(
            valueListenable: homeVisible,
            builder: (_, visible, _) =>
                visible ? const JobManager() : const SizedBox.shrink(),
          ),
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

  Future<void> invokeAction(WidgetTester tester, String action) async {
    if (action == 'Clear History') {
      await tester.tap(
        find
            .descendant(
              of: find.byType(MenuAnchor),
              matching: find.byType(Button),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear Conversion History'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Button, 'Clear History'));
    } else if (action == 'Delete') {
      await tester.ensureVisible(find.bySemanticsLabel('Delete'));
      await tester.tap(find.bySemanticsLabel('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Button, 'Delete'));
    } else {
      await tester.ensureVisible(find.text(action));
      await tester.tap(find.text(action));
      if (action == 'Rename') {
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(Button, 'OK'));
      }
    }
    await tester.pumpAndSettle();
  }

  for (final action in [
    'Stop',
    'Rename',
    'Select folder',
    'Retry export',
    'Clear History',
    'Delete',
  ]) {
    for (final closeHome in [false, true]) {
      testWidgets(
        '$action failure is observed ${closeHome ? 'after closing Home' : 'on Home'}',
        (tester) async {
          final semantics = tester.ensureSemantics();
          try {
            final status = switch (action) {
              'Stop' => JobStatus.running,
              'Delete' || 'Clear History' => JobStatus.completed,
              _ => JobStatus.actionRequired,
            };
            await showJobs(tester, _job(status: status));
            model.operationGate = Completer<void>();
            model.operationError = StateError('Cannot save action');
            await invokeAction(tester, action);
            expect(model.operationCalls, [action]);
            if (closeHome) await tester.pumpWidget(const SizedBox.shrink());
            model.operationGate!.complete();
            await tester.pumpAndSettle();
            expect(
              find.text('Unknown error. Please try again.'),
              closeHome ? findsNothing : findsOneWidget,
            );
            if (!closeHome) expect(find.text('output.wav'), findsOneWidget);
            await tester.pump(const Duration(seconds: 5));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }

  for (final action in ['Rename', 'Select folder', 'Clear History']) {
    testWidgets('$action finishes an accepted operation after Home closes', (
      tester,
    ) async {
      await showJobs(
        tester,
        _job(
          status: action == 'Clear History' ? .completed : .actionRequired,
        ),
      );
      model.operationGate = Completer<void>();
      await invokeAction(tester, action);
      expect(model.operationCalls, [action]);
      await tester.pumpWidget(const SizedBox.shrink());
      model.operationGate!.complete();
      await tester.pumpAndSettle();
      expect(model.operationCalls, [action]);
      expect(tester.takeException(), isNull);
    });
  }

  for (final action in ['Rename', 'Delete', 'Clear History']) {
    testWidgets('$action confirmation cannot mutate a closed Home', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await showJobs(
          tester,
          _job(
            status: action == 'Rename' ? .actionRequired : .completed,
          ),
        );
        if (action == 'Clear History') {
          await tester.tap(
            find
                .descendant(
                  of: find.byType(MenuAnchor),
                  matching: find.byType(Button),
                )
                .first,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Clear Conversion History'));
        } else {
          final trigger = action == 'Delete'
              ? find.bySemanticsLabel('Delete')
              : find.text(action);
          await tester.ensureVisible(trigger);
          await tester.tap(trigger);
        }
        await tester.pumpAndSettle();
        homeVisible.value = false;
        await tester.pumpAndSettle();
        final confirm = action == 'Rename' ? 'OK' : action;
        await tester.tap(find.widgetWithText(Button, confirm));
        await tester.pumpAndSettle();
        expect(model.operationCalls, isEmpty);
        expect(model.removeCount, 0);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets('confirmed deletion finishes cleanup after Home closes', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await showJobs(tester, _job());
      model.operationGate = Completer<void>();
      await invokeAction(tester, 'Delete');
      expect(model.deleteCount, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      model.operationGate!.complete();
      await tester.pumpAndSettle();
      expect(model.removeCount, 1);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  for (final action in ['Open file', 'Share file']) {
    testWidgets('$action does not launch an intent after Home closes', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await showJobs(tester, _job());
        files.checkGate = Completer<void>();
        await tester.ensureVisible(find.bySemanticsLabel(action));
        await tester.tap(find.bySemanticsLabel(action));
        await tester.pump();
        await tester.pumpWidget(const SizedBox.shrink());
        files.checkGate!.complete();
        await tester.pumpAndSettle();
        expect(files.opened, isEmpty);
        expect(files.shared, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
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
  sessionId: status.isProcessing ? 1 : null,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

class _Files extends DirectFileService {
  final opened = <String>[];
  final shared = <String>[];
  Completer<void>? checkGate;
  bool exists = true;
  bool failActions = false;
  @override
  Future<bool> isFileExist(String location) async {
    await checkGate?.future;
    return exists;
  }

  @override
  Future<(String?, Failure?)> chooseSavePath(
    dynamic context, {
    String? initialPath,
  }) async => ('/chosen/output', null);
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
  Completer<void>? operationGate;
  Object? operationError;
  final operationCalls = <String>[];
  int removeCount = 0;
  Future<void> _operation(String name) async {
    operationCalls.add(name);
    await operationGate?.future;
    if (operationError case final error?) throw error;
  }

  @override
  Future<void> removeRunningJob(ConvertJob job, {String? executionId}) =>
      _operation('Stop');
  @override
  Future<Failure?> handleJobRenameAction(ConvertJob job, String name) async {
    await _operation('Rename');
    return null;
  }

  @override
  Future<Failure?> handleJobChooseAnotherPathAction(
    ConvertJob job,
    String path,
  ) async {
    await _operation('Select folder');
    return null;
  }

  @override
  Future<Failure?> retryExport(ConvertJob job) async {
    await _operation('Retry export');
    return null;
  }

  @override
  Future<Failure?> clearFinishedJobs(ClearFinishedJobsOption option) async {
    await _operation('Clear History');
    return null;
  }

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
    await _operation('Delete');
    return deleteFailure;
  }

  @override
  Future<Failure?> removeJob(ConvertJob job) async {
    removeCount++;
    if (removeError case final error?) throw error;
    return null;
  }

  @override
  Stream<List<ConvertJob>> get completedJobsStream =>
      Stream.value(job.status.isDone ? [job] : []);
  @override
  Stream<List<ConvertJob>> get pendingJobsStream => Stream.value([]);
  @override
  Stream<List<ConvertJob>> get runningJobsStream =>
      Stream.value(job.status.isProcessing ? [job] : []);
  @override
  Stream<List<ConvertJob>> get actionRequiredJobsStream =>
      Stream.value(job.status == .actionRequired ? [job] : []);
}

class _Runner implements JobRunnerService {
  @override
  Stream<ConvertJob> get onJobUpdate => const Stream.empty();
  @override
  Stream<JobLog> get onLogUpdate => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
