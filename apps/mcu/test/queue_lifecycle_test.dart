import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:converter/converter.dart';
import 'package:core_storage_base/core_storage_base.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcu/app.dart';
import 'package:mcu/theme_adapter.dart';
import 'package:platform_utils/platform_utils.dart' show PackageInfo;
import 'package:sofluffy_ui/sofluffy_ui.dart';

import 'support/conversion_test_support.dart';

void main() {
  late _Settings settings;
  late _Storage storage;
  late _Runner runner;
  late FluffyThemeData theme;
  setUp(() {
    installShippedAssetHandler();
    PackageInfo.setMockInitialValues(
      appName: 'QA',
      packageName: 'test.queue',
      version: 'seen',
      buildNumber: '1',
      buildSignature: '',
    );
    settings = _Settings()..lastKnownVersion = 'seen';
    storage = _Storage();
    runner = _Runner();
    final notifications = _Notifications();
    injector.registerSingleton<SettingsBox>(settings);
    injector.registerSingleton<ConvertJobStorage>(storage);
    injector.registerSingleton<JobRunnerService>(runner);
    injector.registerSingleton<JobNotificationService>(notifications);
    injector.registerSingleton<JobNotificationCoordinator>(.new(notifications));
    theme = FluffyThemeData.fromJson(
      jsonDecode(
        File('${findRepository().path}/apps/mcu/assets/themes/default.json')
            .readAsStringSync(),
      ),
    );
  });
  tearDown(() async {
    await runner.jobs.close();
    await runner.logs.close();
    settings.changes.dispose();
    clearShippedAssetHandler();
    await injector.reset();
  });
  testWidgets('app teardown releases native queue and log listeners', (
    tester,
  ) async {
    await tester.pumpWidget(MediaConverterUltimate(appTheme: theme));
    await tester.pumpAndSettle();
    expect(runner.jobs.listeners, 1);
    expect(runner.logs.listeners, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(runner.jobs.listeners, 0);
    expect(runner.logs.listeners, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('closing Home during failed recovery catches the late error', (
    tester,
  ) async {
    storage.repairGate = Completer<void>();
    storage.repairFailure = StateError('Database unavailable');
    await tester.pumpWidget(MediaConverterUltimate(appTheme: theme));
    await tester.pump();
    expect(storage.repairs, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    storage.repairGate!.complete();
    await tester.pumpAndSettle();
    expect(runner.jobs.listeners, 0);
    expect(runner.starts, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('theme and language rebuilds preserve one queue owner', (
    tester,
  ) async {
    await tester.pumpWidget(MediaConverterUltimate(appTheme: theme));
    await tester.pumpAndSettle();
    final original = tester
        .element(find.byType(JobManager))
        .read<JobManagerViewModel>();
    await settings.put(CoreSettings.appTheme, ThemeMode.dark);
    await settings.put(CoreSettings.language, 'de');
    await tester.pumpAndSettle();
    expect(
      tester.element(find.byType(JobManager)).read<JobManagerViewModel>(),
      same(original),
    );
    expect(runner.jobs.listeners, 1);
    expect(runner.logs.listeners, 1);
    expect(storage.repairs, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('recreating Home preserves the owner and skips startup repair', (
    tester,
  ) async {
    Widget page(Key key) => ChangeNotifierProvider<JobManagerViewModel>(
      create: (_) => .new(),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: theme.getTheme(isDark: false),
        builder: (_, child) => FluffyTheme(
          data: theme.getFluffyTheme(isDark: false),
          child: child!,
        ),
        home: MainPage(key: key),
      ),
    );
    await tester.pumpWidget(page(const ValueKey('first')));
    await tester.pumpAndSettle();
    final original = tester
        .element(find.byType(JobManager))
        .read<JobManagerViewModel>();
    expect(runner.jobs.listeners, 1);
    expect(storage.repairs, 1);
    final now = DateTime.now();
    await original.enqueueJobs([
      .new(
        id: 'active',
        inputFilePath: '/input.wav',
        outputFileName: 'output.mp3',
        outputExtension: 'mp3',
        outputDirectoryPath: '/outputs',
        command: '[]',
        convertedFilePath: '/stage.mp3',
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    await tester.pumpAndSettle();
    expect(storage.jobs['active']!.status, JobStatus.running);
    final execution = original.activeExecutionId('active');
    expect(runner.starts, 1);
    await tester.pumpWidget(page(const ValueKey('second')));
    await tester.pumpAndSettle();
    expect(
      tester.element(find.byType(JobManager)).read<JobManagerViewModel>(),
      same(original),
    );
    expect(storage.repairs, 1);
    expect(runner.jobs.listeners, 1);
    expect(settings.appLaunchCount, 0);
    expect(original.activeExecutionId('active'), execution);
    expect(storage.jobs['active']!.status, JobStatus.running);
    runner.jobs.controller.add(
      storage.jobs['active']!.copyWith(
        progress: const .new(900),
        duration: const .new(1000),
      ),
    );
    await tester.pumpAndSettle();
    expect(storage.jobs['active']!.progress, 900);
    expect(runner.starts, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(runner.jobs.listeners, 0);
    expect(tester.takeException(), isNull);
  });
}

class _Events<T> {
  final controller = StreamController<T>.broadcast();
  int listeners = 0;
  late final Stream<T> stream = Stream.multi((sink) {
    listeners++;
    final subscription = controller.stream.listen(
      sink.add,
      onError: sink.addError,
      onDone: sink.close,
    );
    sink.onCancel = () async {
      listeners--;
      await subscription.cancel();
    };
  }, isBroadcast: true);
  Future<void> close() => controller.close();
}

class _Runner implements JobRunnerService {
  int starts = 0;
  @override
  Future<ConvertJob> run(ConvertJob job) async {
    starts++;
    return job.copyWith(status: const .new(.running), sessionId: .new(starts));
  }

  final jobs = _Events<ConvertJob>();
  final logs = _Events<JobLog>();
  @override
  Stream<ConvertJob> get onJobUpdate => jobs.stream;
  @override
  Stream<JobLog> get onLogUpdate => logs.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Storage implements ConvertJobStorage {
  @override
  Future<void> onDispose() async {}
  int repairs = 0;
  final jobs = <String, ConvertJob>{};
  Completer<void>? repairGate;
  Object? repairFailure;
  @override
  Future<Failure?> addAll(List<ConvertJob> items) async {
    for (final job in items) {
      jobs[job.id] = job;
    }
    return null;
  }

  @override
  Future<ConvertJob?> get(String id) async => jobs[id];
  @override
  Future<Failure?> update(ConvertJob job) async {
    jobs[job.id] = job;
    return null;
  }

  @override
  Future<List<ConvertJob>> fixInvalidJobs() async {
    repairs++;
    await repairGate?.future;
    if (repairFailure case final error?) throw error;
    return [];
  }

  @override
  Future<List<ConvertJob>> getAllRunningJobs() async =>
      jobs.values.where((job) => job.status.isProcessing).toList();
  @override
  Future<List<ConvertJob>> getNextPendingJobs(int limit) async =>
      jobs.values.where((job) => job.status.isQueued).take(limit).toList();
  @override
  Stream<List<ConvertJob>> watchPendingJobs() => Stream.value([]);
  @override
  Stream<List<ConvertJob>> watchRunningJobs() => Stream.value([]);
  @override
  Stream<List<ConvertJob>> watchCompletedJobs() => Stream.value([]);
  @override
  Stream<List<ConvertJob>> watchActionRequiredJobs() => Stream.value([]);
  @override
  Stream<bool> watchIsJobPendingOrProcessing() => Stream.value(false);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Changes extends ChangeNotifier implements ValueListenable<void> {
  @override
  void get value {}
  void changed() => notifyListeners();
}

class _Settings extends MemorySettings {
  final changes = _Changes();
  @override
  ValueListenable<void> listenTo<T>(List<T> keys) => changes;
  @override
  Future<void> put(dynamic key, dynamic value) async {
    await super.put(key, value);
    changes.changed();
  }
}

class _Notifications implements JobNotificationService {
  @override
  Future<bool> isServiceRunning() async => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
