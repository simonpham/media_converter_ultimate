import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:converter/converter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcu/theme_adapter.dart';
import 'package:platform_utils/platform_utils.dart' show PackageInfo;
import 'package:sofluffy_ui/sofluffy_ui.dart';

import 'support/conversion_test_support.dart';

void main() {
  late FluffyThemeData theme;
  late _ContentBundle bundle;
  late _Settings settings;
  late BuildContext pageContext;

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Test',
      packageName: 'test.content',
      version: 'next',
      buildNumber: '1',
      buildSignature: '',
    );
    installShippedAssetHandler();
    settings = _Settings()..lastKnownVersion = 'previous';
    injector.registerSingleton<SettingsBox>(settings);
    theme = FluffyThemeData.fromJson(
      jsonDecode(
        File('${findRepository().path}/apps/mcu/assets/themes/default.json')
            .readAsStringSync(),
      ),
    );
  });

  tearDown(() async {
    clearShippedAssetHandler();
    await injector.reset();
  });

  Future<void> showPage(WidgetTester tester) async {
    bundle = _ContentBundle();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: theme.getTheme(isDark: false),
        builder: (context, child) => FluffyTheme(
          data: theme.getFluffyTheme(isDark: false),
          child: child!,
        ),
        home: DefaultAssetBundle(
          bundle: bundle,
          child: Builder(
            builder: (context) {
              pageContext = context;
              return const Scaffold(body: Text('Content page'));
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('closing during release loading leaves its version unseen', (
    tester,
  ) async {
    await showPage(tester);
    final pending = ChangelogUtils.check(pageContext);
    await tester.pump();
    expect(bundle.contentRequests, hasLength(1));
    expect(SettingsBox().lastKnownVersion, 'previous');
    await tester.pumpWidget(const SizedBox.shrink());
    bundle.content.complete('<p>Release content</p>');
    await tester.pumpAndSettle();
    await pending;
    expect(SettingsBox().lastKnownVersion, 'previous');
    expect(tester.takeException(), isNull);
  });

  for (final contact in [false, true]) {
    testWidgets(
      '${contact ? 'contact' : 'changelog'} load cannot open a late dialog',
      (tester) async {
        await showPage(tester);
        Object? error;
        final pending =
            (contact
                    ? ContactUtils().sendEmail(pageContext, subject: 'Test')
                    : ChangelogUtils.showChangelogDialog(pageContext))
                .catchError(
                  (Object value) {
                    error = value;
                  },
                );
        await tester.pump();
        expect(bundle.contentRequests, hasLength(1));
        await tester.pumpWidget(const SizedBox.shrink());
        bundle.content.complete('<p>Loaded content</p>');
        await tester.pumpAndSettle();
        await pending;
        expect(error, isNull);
        expect(find.byType(DialogCard), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('localized content fallback retains its original asset bundle', (
    tester,
  ) async {
    SettingsBox().language = 'ja';
    await showPage(tester);
    final pending = ContentUtils.load(pageContext, name: 'changelog');
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    bundle.content.completeError(StateError('Missing Japanese asset'));
    await tester.pumpAndSettle();
    expect(await pending, '<p>English fallback</p>');
    expect(bundle.contentRequests, [
      'assets/content/changelog/ja.html',
      'assets/content/changelog/en.html',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mounted changelog opens once for a new version', (tester) async {
    await showPage(tester);
    final pending = ChangelogUtils.check(pageContext);
    await tester.pump();
    bundle.content.complete('<p>Release content</p>');
    await tester.pumpAndSettle();
    expect(find.byType(DialogCard), findsOneWidget);
    expect(find.text('Release content', findRichText: true), findsOneWidget);
    expect(SettingsBox().lastKnownVersion, 'previous');
    await tester.tap(find.widgetWithText(Button, 'OK'));
    await tester.pumpAndSettle();
    await pending;
    expect(SettingsBox().lastKnownVersion, 'next');
    await ChangelogUtils.check(pageContext);
    await tester.pumpAndSettle();
    expect(find.byType(DialogCard), findsNothing);
    expect(bundle.contentRequests, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  for (final failWrite in [false, true]) {
    testWidgets(
      'release acknowledgment awaits ${failWrite ? 'failed' : 'delayed'} preference save',
      (tester) async {
        await showPage(tester);
        settings.versionWriteGate = Completer<void>();
        settings.failVersionWrite = failWrite;
        var settled = false;
        Object? observedError;
        final pending = ChangelogUtils.check(pageContext).then<void>(
          (_) {
            settled = true;
          },
          onError: (Object error) {
            observedError = error;
            settled = true;
          },
        );
        await tester.pump();
        bundle.content.complete('<p>Release content</p>');
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(Button, 'OK'));
        await tester.pumpAndSettle();
        final settledBeforeSave = settled;
        expect(SettingsBox().lastKnownVersion, 'previous');
        settings.versionWriteGate!.complete();
        await tester.pumpAndSettle();
        await pending;
        expect(settledBeforeSave, isFalse);
        expect(observedError, failWrite ? isStateError : isNull);
        expect(SettingsBox().lastKnownVersion, failWrite ? 'previous' : 'next');
        if (failWrite) {
          settings.versionWriteGate = null;
          settings.failVersionWrite = false;
          final retry = ChangelogUtils.check(pageContext);
          await tester.pumpAndSettle();
          expect(find.byType(DialogCard), findsOneWidget);
          await tester.tap(find.widgetWithText(Button, 'OK'));
          await tester.pumpAndSettle();
          await retry;
          expect(SettingsBox().lastKnownVersion, 'next');
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('closing a pending support page prevents a late dialog', (
    tester,
  ) async {
    await showPage(tester);
    final pending = SettingsPageItem.supportTheDeveloper.handleOpen(
      pageContext,
    );
    await tester.pump();
    expect(bundle.contentRequests, [
      'assets/content/support_developer/en.html',
    ]);
    await tester.pumpWidget(const SizedBox.shrink());
    bundle.content.complete('<p>Support content</p>');
    await tester.pumpAndSettle();
    await pending;
    expect(find.byType(DialogCard), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _ContentBundle extends CachingAssetBundle {
  final content = Completer<String>();
  final contentRequests = <String>[];
  @override
  Future<ByteData> load(String key) => rootBundle.load(key);
  @override
  Future<String> loadString(String key, {bool cache = true}) {
    if (!key.startsWith('assets/content/')) {
      return rootBundle.loadString(key, cache: cache);
    }
    contentRequests.add(key);
    return contentRequests.length == 1
        ? content.future
        : Future.value('<p>English fallback</p>');
  }
}

class _Settings extends MemorySettings {
  Completer<void>? versionWriteGate;
  bool failVersionWrite = false;
  @override
  Future<void> put(dynamic key, dynamic value) async {
    if (key == CoreSettings.lastKnownVersion && value == 'next') {
      await versionWriteGate?.future;
      if (failVersionWrite) throw StateError('Preference write failed');
    }
    await super.put(key, value);
  }
}
