import 'dart:async';

import 'package:converter/converter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

import 'support/conversion_test_support.dart';

void main() {
  late _Settings settings;
  late _Notifications notifications;

  setUp(() {
    settings = _Settings();
    settings.values[JobRunnerSettings.keepAppRunning] = false;
    notifications = _Notifications();
    injector.registerSingleton<SettingsBox>(settings);
    injector.registerSingleton<JobNotificationService>(notifications);
    installShippedAssetHandler();
  });

  tearDown(() async {
    clearShippedAssetHandler();
    await injector.reset();
    settings.changes.dispose();
  });

  Future<void> showSetting(WidgetTester tester) async {
    await tester.pumpWidget(
      FluffyTheme(
        data: FluffyThemeData.fallback(),
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SettingsItem(item: .keepAppRunning)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapSetting(WidgetTester tester) async {
    await tester.tap(find.text('Keep App Running'));
    await tester.pumpAndSettle();
  }

  testWidgets('closing during permission lookup does not open a late prompt', (
    tester,
  ) async {
    notifications.checkGates[0] = Completer<void>();
    await showSetting(tester);
    await tapSetting(tester);
    expect(notifications.checks, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    notifications.checkGates[0]!.complete();
    await tester.pumpAndSettle();
    expect(notifications.requests, 0);
    expect(notifications.initializations, 0);
    expect(settings.keepAppRunning, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'repeated taps share one permission operation and allow later disable',
    (tester) async {
      notifications.granted = true;
      notifications.checkGates[0] = Completer<void>();
      await showSetting(tester);
      await tapSetting(tester);
      await tapSetting(tester);
      expect(notifications.checks, 1);
      expect(notifications.requests, 0);
      notifications.checkGates[0]!.complete();
      await tester.pumpAndSettle();
      expect(settings.keepAppRunning, isTrue);
      expect(notifications.requests, 1);
      expect(notifications.initializations, 1);
      await tapSetting(tester);
      expect(settings.keepAppRunning, isFalse);
      expect(notifications.requests, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'canceling the permission prompt keeps the switch off and retry available',
    (tester) async {
      await showSetting(tester);
      await tester.tap(find.byType(SwitchToggle));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(find.text('Notification Permission'), findsOneWidget);
      await tester.tap(find.widgetWithText(Button, 'Cancel'));
      await tester.pumpAndSettle();
      expect(settings.keepAppRunning, isFalse);
      expect(notifications.requests, 0);
      await tester.tap(find.byType(SwitchToggle));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(find.text('Notification Permission'), findsOneWidget);
      notifications.grantOnRequest = true;
      await tester.tap(find.widgetWithText(Button, 'Enable'));
      await tester.pumpAndSettle();
      expect(settings.keepAppRunning, isTrue);
      expect(notifications.requests, 1);
      expect(notifications.initializations, 1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final stage in ['request', 'recheck', 'initialization']) {
    testWidgets('closing during $stage leaves protection disabled', (
      tester,
    ) async {
      notifications.granted = true;
      final gate = Completer<void>();
      switch (stage) {
        case 'request':
          notifications.requestGate = gate;
        case 'recheck':
          notifications.checkGates[1] = gate;
        case 'initialization':
          notifications.initGate = gate;
      }
      await showSetting(tester);
      await tapSetting(tester);
      expect(notifications.requests, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      gate.complete();
      await tester.pumpAndSettle();
      expect(settings.keepAppRunning, isFalse);
      expect(notifications.initializations, stage == 'initialization' ? 1 : 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'native initialization failure is shown and permits corrected retry',
    (tester) async {
      notifications.granted = true;
      notifications.failInitialization = true;
      await showSetting(tester);
      await tapSetting(tester);
      expect(settings.keepAppRunning, isFalse);
      expect(find.text('Unknown error. Please try again.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      notifications.failInitialization = false;
      await tapSetting(tester);
      expect(settings.keepAppRunning, isTrue);
      expect(notifications.initializations, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('denied system permission never enables protection', (
    tester,
  ) async {
    await showSetting(tester);
    await tapSetting(tester);
    await tester.tap(find.widgetWithText(Button, 'Enable'));
    await tester.pumpAndSettle();
    expect(settings.keepAppRunning, isFalse);
    expect(notifications.requests, 1);
    expect(notifications.initializations, 0);
    await tapSetting(tester);
    expect(find.text('Notification Permission'), findsOneWidget);
    await tester.tap(find.widgetWithText(Button, 'Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed preference write preserves the enabled setting for retry',
    (tester) async {
      settings.values[JobRunnerSettings.keepAppRunning] = true;
      settings.failWrites = true;
      await showSetting(tester);
      await tapSetting(tester);
      expect(settings.keepAppRunning, isTrue);
      expect(find.text('Unknown error. Please try again.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      settings.failWrites = false;
      await tapSetting(tester);
      expect(settings.keepAppRunning, isFalse);
      expect(notifications.requests, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Changes extends ChangeNotifier implements ValueListenable<void> {
  @override
  void get value {}
  void changed() => notifyListeners();
}

class _Settings extends MemorySettings {
  final changes = _Changes();
  bool failWrites = false;
  @override
  ValueListenable<void> listenTo<T>(List<T> keys) => changes;
  @override
  Future<void> put(dynamic key, dynamic value) async {
    if (failWrites) throw StateError('Preference write failed');
    await super.put(key, value);
    changes.changed();
  }
}

class _Notifications implements JobNotificationService {
  final checkGates = <int, Completer<void>>{};
  Completer<void>? requestGate;
  Completer<void>? initGate;
  bool granted = false;
  bool grantOnRequest = false;
  bool failInitialization = false;
  int checks = 0;
  int requests = 0;
  int initializations = 0;
  @override
  Future<bool> isNotificationPermissionGranted() async {
    final index = checks++;
    await checkGates[index]?.future;
    return granted;
  }

  @override
  Future<void> requestPermission() async {
    requests++;
    await requestGate?.future;
    if (grantOnRequest) granted = true;
  }

  @override
  Future<void> init(JobNotificationServiceInitParams params) async {
    initializations++;
    await initGate?.future;
    if (failInitialization) throw StateError('Native initialization failed');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
