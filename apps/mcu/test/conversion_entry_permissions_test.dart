import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:converter/converter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcu/theme_adapter.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

import 'support/conversion_test_support.dart';

void main() {
  const deviceChannel = MethodChannel('dev.fluttercommunity.plus/device_info');
  const permissionChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );
  late _Manager manager;
  late GoRouter router;
  late FluffyThemeData theme;
  var sdk = 30;
  var requests = 0;
  Completer<void>? permissionGate;

  setUp(() {
    requests = 0;
    permissionGate = null;
    installShippedAssetHandler();
    injector.registerSingleton<SettingsBox>(
      MemorySettings()..lastOutputDirectoryPath = '/saved-output',
    );
    manager = _Manager();
    theme = FluffyThemeData.fromJson(
      jsonDecode(
        File('${findRepository().path}/apps/mcu/assets/themes/default.json')
            .readAsStringSync(),
      ),
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      deviceChannel,
      (_) async => {
        'version': {
          'baseOS': '',
          'codename': 'REL',
          'incremental': '0',
          'previewSdkInt': 0,
          'release': 'test',
          'sdkInt': sdk,
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
        'time': 0,
        'isLowRamDevice': false,
        'freeDiskSize': 0,
        'totalDiskSize': 0,
        'physicalRamSize': 0,
        'availableRamSize': 0,
      },
    );
    messenger.setMockMethodCallHandler(permissionChannel, (call) async {
      if (call.method == 'requestPermissions') {
        requests++;
        await permissionGate?.future;
        return {for (final permission in call.arguments as List) permission: 0};
      }
      throw StateError('Unexpected permission operation: ${call.method}');
    });
    router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const JobManager()),
        GoRoute(
          path: '/job-maker',
          name: JobMaker.routeName,
          builder: (_, _) =>
              const Scaffold(body: Center(child: Text('Setup opened'))),
        ),
      ],
    );
  });

  tearDown(() async {
    router.dispose();
    manager.dispose();
    clearShippedAssetHandler();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(deviceChannel, null);
    messenger.setMockMethodCallHandler(permissionChannel, null);
    await injector.reset();
  });

  Future<void> create(WidgetTester tester) async {
    await tester.pumpWidget(
      ScreenSizeScope(
        child: ChangeNotifierProvider<JobManagerViewModel>.value(
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
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Button, 'Create'));
    await tester.pumpAndSettle();
  }

  for (final api in [30, 31, 32, 33, 36]) {
    testWidgets('API $api opens setup without broad storage permission', (
      tester,
    ) async {
      sdk = api;
      await create(tester);
      expect(requests, 0);
      expect(find.text('Setup opened'), findsOneWidget);
      expect(find.text('Storage permission denied'), findsNothing);
      expect(SettingsBox().lastOutputDirectoryPath, '/saved-output');
      router.pop(<ConvertJob>[]);
      await tester.pumpAndSettle();
      expect(
        tester.widget<Button>(find.widgetWithText(Button, 'Create')).enable,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant({TargetPlatform.android}));
  }

  for (final api in [28, 29]) {
    testWidgets('API $api retains the legacy storage permission gate', (
      tester,
    ) async {
      sdk = api;
      await create(tester);
      expect(requests, 1);
      expect(find.text('Setup opened'), findsNothing);
      expect(find.text('Storage permission denied'), findsOneWidget);
      await tester.tap(find.widgetWithText(Button, 'Go back'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Button>(find.widgetWithText(Button, 'Create')).enable,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant({TargetPlatform.android}));
  }

  testWidgets('closing Home during a permission request stops setup safely', (
    tester,
  ) async {
    sdk = 28;
    permissionGate = Completer<void>();
    await create(tester);
    expect(requests, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    permissionGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Storage permission denied'), findsNothing);
    expect(find.text('Setup opened'), findsNothing);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.android}));
}

class _Manager extends ChangeNotifier implements JobManagerViewModel {
  @override
  Stream<List<ConvertJob>> get completedJobsStream => Stream.value([]);
  @override
  Stream<List<ConvertJob>> get pendingJobsStream => Stream.value([]);
  @override
  Stream<List<ConvertJob>> get runningJobsStream => Stream.value([]);
  @override
  Stream<List<ConvertJob>> get actionRequiredJobsStream => Stream.value([]);
  @override
  Future<void> addJobs(List<ConvertJob> jobs) async => expect(jobs, isEmpty);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
