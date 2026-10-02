import 'dart:async';
import 'dart:convert';

import 'package:converter/converter.dart';
import 'package:core_storage_base/core_storage_base.dart';
import 'package:core_storage_isar/core_storage_isar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mcu/app.dart';
import 'package:platform_utils/platform_utils.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

/// Run through test_android_background.sh; it resumes only the isolated QA
/// activity after the explicit MCU_QA_RESUME_ACTIVITY request below.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final prefix = 'MCU_Background_QA_${DateTime.now().microsecondsSinceEpoch}';
  late Directory directory;
  late Directory pickedDirectory;
  late File picked;
  late Isar isar;
  late JobMakerViewModel maker;
  late JobManagerViewModel manager;
  late _Settings settings;
  late JobNotificationService notifications;
  late JobNotificationCoordinator coordinator;
  final lifecycle = _Lifecycle();
  ConvertJob? accepted;
  bool databaseOpen = false;
  bool managerOwnedByApp = false;

  Future<void> openDatabase() async {
    isar = await Isar.open(
      [IsarConvertJobSchema],
      directory: directory.path,
      name: 'background-qa',
    );
    databaseOpen = true;
    injector.registerSingleton<ConvertJobStorage>(
      ConvertJobIsarStorage(isar: isar),
    );
  }

  setUpAll(() async {
    final files = DirectFileService();
    injector.registerSingleton<FileService>(files);
    final cache = await files.getAppCacheDirectory();
    directory = await cache.createTemp(prefix);
    // Exercise real picker-cache ownership and rollback using only QA files.
    pickedDirectory = Directory('${cache.path}/file_picker/$prefix');
    await pickedDirectory.create(recursive: true);
    picked = File('${pickedDirectory.path}/source Việt.wav');
    final generated = await FFmpegKit.executeWithArguments([
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=440:sample_rate=48000:duration=20',
      '-c:a',
      'pcm_s16le',
      picked.path,
    ]);
    expect(
      ReturnCode.isSuccess(await generated.getReturnCode()),
      isTrue,
      reason: await generated.getAllLogsAsString(),
    );
    settings = _Settings();
    injector.registerSingleton<SettingsBox>(settings);
    injector.registerSingleton<JobConfigurationData>(_Configurations());
    injector.registerSingleton<LogData>(_Logs());
    injector.registerSingleton<JobRunnerService>(FfmpegJobRunnerService());
    notifications = JobNotificationServiceImpl();
    injector.registerSingleton<JobNotificationService>(notifications);
    coordinator = JobNotificationCoordinator(notifications);
    injector.registerSingleton<JobNotificationCoordinator>(coordinator);
    FlutterForegroundTask.initCommunicationPort();
    await notifications.init(
      const JobNotificationServiceInitParams(
        channelName: 'Native background QA',
        channelDescription: 'Owned QA conversion',
      ),
    );
    await openDatabase();
    manager = JobManagerViewModel();
    maker = JobMakerViewModel(
      formatConfigModel: FormatConfigModel.fromJson(
        jsonDecode(await rootBundle.loadString('assets/configs/format.json')),
      ),
      translations: const {},
    );
    await maker.addFiles([picked]);
    await maker.applyPreset(.musicMp3);
    maker.setOutputDirectoryPath(OutputDestination.appStorage);
    maker.setOutputFileName(picked.path, '$prefix Việt.mp3');
    maker.setFileTrim(
      picked.path,
      const FileTrimResult(
        trim: ConversionTrim(
          start: Duration(seconds: 1),
          end: Duration(seconds: 17),
        ),
        duration: Duration(seconds: 20),
      ),
    );
    WidgetsBinding.instance.addObserver(lifecycle);
  });

  tearDownAll(() async {
    WidgetsBinding.instance.removeObserver(lifecycle);
    maker.dispose();
    if (!managerOwnedByApp) manager.dispose();
    await coordinator.update(shouldRun: false);
    if (accepted case final job?) {
      await injector<FileService>().cleanUpInputFile(jobId: job.id);
      await injector<FileService>().deleteFileAtPath(job.convertedFilePath);
      final saved = databaseOpen
          ? await ConvertJobStorage.getInstance().get(job.id)
          : null;
      if (saved?.status == .completed) {
        await injector<FileService>().deleteOutput(saved!.outputLocation);
      }
    }
    if (databaseOpen) await isar.close(deleteFromDisk: true);
    await injector.reset();
    settings.changes.dispose();
    if (await pickedDirectory.exists()) {
      await pickedDirectory.delete(recursive: true);
    }
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  testWidgets(
    'queue retry converts and exports after the real QA activity backgrounds',
    (tester) async {
      final original = await picked.readAsBytes();
      final selected = {...maker.selectedValues};
      final name = maker.outputFileNames[picked.path];
      final trim = maker.trimFor(picked.path);
      await isar.close();
      databaseOpen = false;
      await expectLater(
        maker.cook(onSubmitJobs: manager.enqueueJobs),
        throwsA(isA<FailedToQueueJobsFailure>()),
      );
      expect(await picked.readAsBytes(), original);
      expect(maker.outputFileNames[picked.path], name);
      expect(maker.trimFor(picked.path), trim);
      expect(maker.selectedValues, selected);
      await injector.unregister<ConvertJobStorage>();
      await openDatabase();
      expect(await ConvertJobStorage.getInstance().count(), 0);
      printLog('[Native background QA] failed save restored real picker input');

      // The rejected-save fixture has no native work. Hand the accepted retry
      // to the production app provider, which owns and disposes its manager.
      manager.dispose();
      managerOwnedByApp = true;
      await settings.put(
        CoreSettings.lastKnownVersion,
        (await PackageInfo.fromPlatform()).version,
      );
      final theme = FluffyThemeData.fromJson(
        jsonDecode(await rootBundle.loadString('assets/themes/default.json')),
      );
      try {
        await tester.pumpWidget(MediaConverterUltimate(appTheme: theme));
        await tester.pumpAndSettle();
        manager = tester
            .element(find.byType(JobManager))
            .read<JobManagerViewModel>();
        await manager.initialize();
        expect(find.byType(MainPage), findsOneWidget);
        // Initialization was explicit above. Avoid system permission dialogs in QA;
        // production permission/cancellation flows are covered by widget tests.
        await settings.put(JobRunnerSettings.keepAppRunning, true);
        final jobs = await maker.cook(
          onSubmitJobs: (jobs) async {
            // Slow fixture input reads so the real lifecycle transition occurs while
            // the native runner is active; shipped output settings remain unchanged.
            final paced = [
              for (final job in jobs)
                job.copyWith(
                  command: .new(
                    jsonEncode([
                      '-re',
                      ...CommandBuilder.parseCommand(job.command),
                    ]),
                  ),
                ),
            ];
            accepted = paced.single;
            await manager.enqueueJobs(paced);
          },
        );
        final job = jobs.single;
        await _waitFor(
          () async =>
              (await ConvertJobStorage.getInstance().get(job.id))?.status ==
              .running,
        );
        expect(await File(accepted!.inputFilePath).exists(), isTrue);
        expect(await notifications.isServiceRunning(), isFalse);
        final execution = manager.activeExecutionId(job.id);
        final session = (await ConvertJobStorage.getInstance().get(job.id))!
            .sessionId;
        await settings.put(CoreSettings.appTheme, ThemeMode.dark);
        await settings.put(CoreSettings.language, 'vi');
        await tester.pumpAndSettle();
        expect(
          tester.element(find.byType(JobManager)).read<JobManagerViewModel>(),
          same(manager),
        );
        expect(manager.activeExecutionId(job.id), execution);
        expect(
          (await ConvertJobStorage.getInstance().get(job.id))!.sessionId,
          session,
        );
        printLog(
          '[Native background QA] actual app preserves its running owner across settings rebuilds',
        );
        FlutterForegroundTask.minimizeApp();
        await _waitFor(() async => lifecycle.backgrounded);
        await _waitFor(notifications.isServiceRunning);
        expect(lifecycle.states, contains(AppLifecycleState.paused));
        printLog(
          '[Native background QA] actual paused activity has foreground service',
        );
        await _waitFor(() async {
          final current = await ConvertJobStorage.getInstance().get(job.id);
          if (current?.status.isFailure == true) {
            fail('Native conversion failed: ${LogData().getLog(job.id)}');
          }
          return current?.status == .completed;
        }, timeout: const Duration(seconds: 40));
        expect(lifecycle.backgrounded, isTrue);
        final completed = (await ConvertJobStorage.getInstance().get(job.id))!;
        expect(completed.outputFileName, name);
        expect(await File(completed.outputLocation).length(), greaterThan(0));
        final probe = await FFprobeKit.getMediaInformation(
          completed.outputLocation,
        );
        expect(
          double.parse(probe.getMediaInformation()!.getDuration()!),
          closeTo(16, 0.2),
        );
        await _waitFor(() async => !await notifications.isServiceRunning());
        await _waitFor(
          () async => !await File(completed.inputFilePath).exists(),
        );
        printLog(
          '[Native background QA] completed export and stopped service while backgrounded',
        );
      } finally {
        if (lifecycle.backgrounded) {
          printLog('MCU_QA_RESUME_ACTIVITY');
          await _waitFor(
            () async => !lifecycle.backgrounded,
            timeout: const Duration(seconds: 30),
          );
        }
        if (accepted case final job?) {
          final current = await ConvertJobStorage.getInstance().get(job.id);
          if (current?.status.isProcessing == true) {
            await manager.removeRunningJob(current!);
            await _waitFor(
              () async =>
                  (await ConvertJobStorage.getInstance().get(job.id))
                      ?.status
                      .isDone ==
                  true,
            );
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await coordinator.update(shouldRun: false);
      }
    },
  );
}

Future<void> _waitFor(
  Future<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final until = DateTime.now().add(timeout);
  while (!await condition()) {
    if (DateTime.now().isAfter(until)) {
      throw TimeoutException(
        'Native QA condition did not become true',
        timeout,
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

class _Lifecycle extends WidgetsBindingObserver {
  final states = <AppLifecycleState>[];
  bool get backgrounded => switch (WidgetsBinding.instance.lifecycleState) {
    .hidden || .paused || .detached => true,
    _ => false,
  };
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => states.add(state);
}

class _Changes extends ChangeNotifier implements ValueListenable<void> {
  @override
  void get value {}
  void changed() => notifyListeners();
}

class _Settings implements SettingsBox {
  final values = <dynamic, dynamic>{};
  final changes = _Changes();
  @override
  dynamic get(dynamic key, {required dynamic defaultValue}) =>
      values.containsKey(key) ? values[key] : defaultValue;
  @override
  Future<void> put(dynamic key, dynamic value) async {
    values[key] = value;
    changes.changed();
  }

  @override
  ValueListenable<void> listenTo<T>(List<T> keys) => changes;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Configurations implements JobConfigurationData {
  final values = <dynamic, dynamic>{};
  @override
  dynamic get(dynamic key, {required dynamic defaultValue}) =>
      values[key] ?? defaultValue;
  @override
  Future<void> put(dynamic key, dynamic value) async => values[key] = value;
  @override
  Future<void> onDispose() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Logs implements LogData {
  final values = <dynamic, dynamic>{};
  @override
  dynamic get(dynamic key, {required dynamic defaultValue}) =>
      values[key] ?? defaultValue;
  @override
  Future<void> put(dynamic key, dynamic value) async => values[key] = value;
  @override
  Future<void> onDispose() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
