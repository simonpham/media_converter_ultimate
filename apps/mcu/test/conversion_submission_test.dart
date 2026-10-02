import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:converter/converter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcu/theme_adapter.dart';
import 'package:platform_utils/platform_utils.dart'
    show DirectFileService, FileService;
import 'package:sofluffy_ui/sofluffy_ui.dart';

import 'support/conversion_test_support.dart';

void main() {
  const deviceChannel = MethodChannel('dev.fluttercommunity.plus/device_info');
  late Directory directory;
  late _Files files;
  late _Manager manager;
  late GoRouter router;
  late FluffyThemeData theme;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('mcu-submission-');
    files = _Files(directory);
    installShippedAssetHandler();
    injector.registerSingleton<SettingsBox>(
      MemorySettings()..lastOutputDirectoryPath = '${directory.path}/output',
    );
    injector.registerSingleton<JobConfigurationData>(MemoryConfigurations());
    injector.registerSingleton<FileService>(files);
    manager = _Manager();
    theme = FluffyThemeData.fromJson(
      jsonDecode(
        File('${findRepository().path}/apps/mcu/assets/themes/default.json')
            .readAsStringSync(),
      ),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          deviceChannel,
          (_) async => {
            'version': {
              'baseOS': '',
              'codename': 'REL',
              'incremental': '0',
              'previewSdkInt': 0,
              'release': 'test',
              'sdkInt': 36,
              'securityPatch': '',
            },
            for (final field in [
              'board',
              'bootloader',
              'brand',
              'device',
              'display',
              'fingerprint',
              'hardware',
              'host',
              'id',
              'manufacturer',
              'model',
              'product',
              'tags',
              'type',
            ])
              field: 'test',
            'isPhysicalDevice': false,
            'isLowRamDevice': false,
            'freeDiskSize': 0,
            'totalDiskSize': 0,
            'physicalRamSize': 0,
            'availableRamSize': 0,
          },
        );
    router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const JobManager()),
        GoRoute(
          path: '/job-maker',
          name: JobMaker.routeName,
          builder: (_, state) => JobMaker.fromRouterState(state),
        ),
      ],
    );
  });

  tearDown(() async {
    router.dispose();
    manager.dispose();
    clearShippedAssetHandler();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(deviceChannel, null);
    await injector.reset();
    directory.deleteSync(recursive: true);
  });

  testWidgets(
    'Home keeps Review and its draft after save failure, then queues retry once',
    (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<JobManagerViewModel>.value(
          value: manager,
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: theme.getTheme(isDark: false),
            builder: (context, child) => FluffyTheme(
              data: theme.getFluffyTheme(isDark: false),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Button, 'Create'));
      await tester.pumpAndSettle();
      expect(find.byType(JobMaker), findsOneWidget);
      await tester.tap(find.widgetWithText(Button, 'Add Files'));
      await tester.pumpAndSettle();
      final model = tester
          .element(find.byType(JobMakerFilePicker))
          .read<JobMakerViewModel>();
      await model.applyPreset(.musicMp3);
      model.setOutputFileName(files.source.path, 'holiday.mp3');
      const trim = ConversionTrim(
        start: Duration(seconds: 1),
        end: Duration(seconds: 3),
      );
      model.setFileTrim(
        files.source.path,
        const FileTrimResult(
          trim: trim,
          duration: Duration(seconds: 4),
        ),
      );
      await tester.pumpAndSettle();
      for (var step = 0; step < 3; step++) {
        await tester.tap(find.widgetWithText(Button, 'Next'));
        await tester.pumpAndSettle();
      }
      expect(find.widgetWithText(Button, 'Start Conversion'), findsOneWidget);
      final selection = {...model.selectedValues};
      manager.submitGate = Completer<void>();
      manager.failSubmission = true;
      await tester.tap(find.widgetWithText(Button, 'Start Conversion'));
      await tester.pumpAndSettle();
      expect(manager.submitted, hasLength(1));
      expect(model.isPreparingJobs, isTrue);
      expect(find.byType(JobMaker), findsOneWidget);
      final busy = find.widgetWithText(Button, 'Preparing conversions…');
      expect(tester.widget<Button>(busy).enable, isFalse);
      // Even an accidental second activation cannot submit another batch.
      await tester.tap(busy);
      await tester.pump();
      expect(manager.submitted, hasLength(1));
      manager.submitGate!.complete();
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Could not add these files to the queue.'),
        findsOneWidget,
      );
      expect(find.byType(JobMaker), findsOneWidget);
      expect(model.selectedFiles.single.path, files.source.path);
      expect(model.outputFileNames[files.source.path], 'holiday.mp3');
      expect(model.trimFor(files.source.path), trim);
      expect(model.selectedValues, selection);
      expect(model.isPreparingJobs, isFalse);
      expect(manager.accepted, isEmpty);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      manager.failSubmission = false;
      manager.submitGate = null;
      await tester.tap(find.widgetWithText(Button, 'Start Conversion'));
      await tester.pumpAndSettle();
      expect(find.byType(JobMaker), findsNothing);
      expect(manager.submitted, hasLength(2));
      expect(manager.accepted, hasLength(1));
      expect(manager.addJobsCalls, 0);
      final job = manager.accepted.single;
      expect(job.outputFileName, 'holiday.mp3');
      expect(job.outputDirectoryPath, '${directory.path}/output');
      final arguments = jsonDecode(job.command) as List;
      expect(
        double.parse(arguments[arguments.indexOf('-ss') + 1] as String),
        1,
      );
      expect(double.parse(arguments[arguments.indexOf('-t') + 1] as String), 2);
      expect(files.cleanups, [manager.submitted.first.single.id]);
      expect(files.cleanups, isNot(contains(job.id)));
      expect(files.source.existsSync(), isTrue);
      await tester.scrollUntilVisible(
        find.text('holiday.mp3'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('holiday.mp3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Files(final Directory directory) extends DirectFileService {
  late final File source = File('${directory.path}/source.wav')
    ..writeAsBytesSync([82, 73, 70, 70, 36, 0, 0, 0, 87, 65, 86, 69]);
  final cleanups = <String>[];
  @override
  Future<List<File>> chooseFiles(dynamic context) async => [source];
  @override
  Future<String?> getFileMimeType(File file) async => 'audio/wav';
  @override
  Future<bool> isFileExist(String path) async => path == source.path;
  @override
  Future<bool> outputExists(String destination, String name) async => false;
  @override
  Future<Directory> getAppCacheDirectory() async => directory;
  @override
  Future<Directory> getConvertTemporaryDirectory(String? prefix) async =>
      directory;
  @override
  Future<String?> movePickedFileToInputFolder({
    required String jobId,
    required String inputFilePath,
    required String appCachedPath,
  }) async => inputFilePath;
  @override
  Future<void> cleanUpInputFile({required String jobId}) async =>
      cleanups.add(jobId);
}

class _Manager extends ChangeNotifier implements JobManagerViewModel {
  final submitted = <List<ConvertJob>>[];
  final accepted = <ConvertJob>[];
  Completer<void>? submitGate;
  bool failSubmission = false;
  int addJobsCalls = 0;
  @override
  Future<void> enqueueJobs(List<ConvertJob> jobs) async {
    submitted.add(jobs);
    await submitGate?.future;
    if (failSubmission) throw const FailedToQueueJobsFailure();
    accepted.addAll(jobs);
    notifyListeners();
  }

  @override
  Future<void> addJobs(List<ConvertJob> jobs) async => addJobsCalls++;
  @override
  Stream<List<ConvertJob>> get pendingJobsStream => Stream.value([...accepted]);
  @override
  Stream<List<ConvertJob>> get completedJobsStream => Stream.value([]);
  @override
  Stream<List<ConvertJob>> get runningJobsStream => Stream.value([]);
  @override
  Stream<List<ConvertJob>> get actionRequiredJobsStream => Stream.value([]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
