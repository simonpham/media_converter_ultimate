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
  late _Notifications notifications;
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
    notifications = _Notifications();
    injector.registerSingleton<SettingsBox>(settings);
    injector.registerSingleton<ConvertJobStorage>(storage);
    injector.registerSingleton<JobRunnerService>(runner);
    injector.registerSingleton<JobNotificationService>(notifications);
    injector.registerLazySingleton<JobNotificationCoordinator>(
      () => .new(notifications),
    );
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
    await storage.processing.close();
    settings.changes.dispose();
    clearShippedAssetHandler();
    await injector.reset();
  });
  for (final processing in [false, true]) {
    testWidgets(
      'activity query failure preserves processing=$processing until next event',
      (
        tester,
      ) async {
        await settings.put(JobRunnerSettings.keepAppRunning, true);
        try {
          await tester.pumpWidget(MediaConverterUltimate(appTheme: theme));
          await tester.pumpAndSettle();
          expect(notifications.initializations, 1);
          storage.processing.add(processing);
          await tester.pumpAndSettle();
          expect(notifications.events, isEmpty);
          tester.binding.handleAppLifecycleStateChanged(.paused);
          await tester.pumpAndSettle();
          expect(notifications.running, processing);
          expect(notifications.events, processing ? ['start'] : isEmpty);
          storage.processing.addError(StateError('Activity query unavailable'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(notifications.running, processing);
          expect(notifications.events, processing ? ['start'] : isEmpty);
          storage.processing.add(!processing);
          await tester.pumpAndSettle();
          expect(notifications.running, !processing);
          tester.binding.handleAppLifecycleStateChanged(.resumed);
          await tester.pumpAndSettle();
          expect(notifications.running, isFalse);
          expect(notifications.events, ['start', 'stop']);
          expect(settings.keepAppRunning, isTrue);
        } finally {
          tester.binding.handleAppLifecycleStateChanged(.resumed);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        }
        storage.processing.addError(StateError('Event after app teardown'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final stage in ['permission', 'initialization']) {
    for (final closeApp in [false, true]) {
      testWidgets(
        '$stage startup failure is observed with app closed=$closeApp',
        (
          tester,
        ) async {
          await settings.put(JobRunnerSettings.keepAppRunning, true);
          final gate = Completer<void>();
          final error = StateError('Native $stage unavailable');
          if (stage == 'permission') {
            notifications.permissionGate = gate;
            notifications.permissionFailure = error;
          } else {
            notifications.initGate = gate;
            notifications.initFailure = error;
          }
          await tester.pumpWidget(MediaConverterUltimate(appTheme: theme));
          await tester.pumpAndSettle();
          expect(notifications.permissions, 1);
          expect(notifications.initializations, stage == 'permission' ? 0 : 1);
          if (closeApp) {
            await tester.pumpWidget(const SizedBox.shrink());
          }
          gate.complete();
          await tester.pumpAndSettle();
          expect(settings.keepAppRunning, isTrue);
          expect(tester.takeException(), isNull);
          if (!closeApp) {
            expect(find.byType(JobManager), findsOneWidget);
            expect(runner.jobs.listeners, 1);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
          }
          expect(runner.jobs.listeners, 0);
        },
      );
    }
  }
  testWidgets('turning background setting off cancels pending startup setup', (
    tester,
  ) async {
    await settings.put(JobRunnerSettings.keepAppRunning, true);
    notifications.permissionGate = Completer<void>();
    await tester.pumpWidget(MediaConverterUltimate(appTheme: theme));
    await tester.pumpAndSettle();
    expect(notifications.permissions, 1);
    await settings.put(JobRunnerSettings.keepAppRunning, false);
    notifications.permissionGate!.complete();
    await tester.pumpAndSettle();
    expect(notifications.initializations, 0);
    expect(settings.keepAppRunning, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  testWidgets('closing app cancels pending startup permission setup', (
    tester,
  ) async {
    await settings.put(JobRunnerSettings.keepAppRunning, true);
    notifications.permissionGate = Completer<void>();
    await tester.pumpWidget(MediaConverterUltimate(appTheme: theme));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    notifications.permissionGate!.complete();
    await tester.pumpAndSettle();
    expect(notifications.initializations, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('startup initializes enabled background service only once', (
    tester,
  ) async {
    await settings.put(JobRunnerSettings.keepAppRunning, true);
    await tester.pumpWidget(MediaConverterUltimate(appTheme: theme));
    await tester.pumpAndSettle();
    await settings.put(CoreSettings.language, 'de');
    await settings.put(CoreSettings.appTheme, ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(notifications.permissions, 1);
    expect(notifications.initializations, 1);
    expect(notifications.parameters!.channelName, kAppName);
    expect(notifications.parameters!.channelDescription, isNotEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
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
    Widget page(Key key) => ScreenSizeScope(
      child: ChangeNotifierProvider<JobManagerViewModel>(
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
  final processing = StreamController<bool>.broadcast();
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
  Stream<bool> watchIsJobPendingOrProcessing() => processing.stream;
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
  bool running = false;
  final events = <String>[];
  int permissions = 0;
  int initializations = 0;
  Completer<void>? permissionGate;
  Completer<void>? initGate;
  Object? permissionFailure;
  Object? initFailure;
  JobNotificationServiceInitParams? parameters;
  @override
  Future<void> requestPermission() async {
    permissions++;
    await permissionGate?.future;
    if (permissionFailure case final error?) throw error;
  }

  @override
  Future<void> init(JobNotificationServiceInitParams params) async {
    initializations++;
    parameters = params;
    await initGate?.future;
    if (initFailure case final error?) throw error;
  }

  @override
  Future<bool> isServiceRunning() async => running;
  @override
  Future<void> start(JobNotificationServiceStartParams params) async {
    events.add('start');
    running = true;
  }

  @override
  Future<void> stop() async {
    events.add('stop');
    running = false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
