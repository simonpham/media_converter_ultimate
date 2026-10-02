import 'dart:async';

import 'package:converter/converter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/conversion_test_support.dart';

void main() {
  const packageChannel = MethodChannel(
    'dev.fluttercommunity.plus/package_info',
  );

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(packageChannel, null);
    await injector.reset();
  });

  testWidgets('late package lookup does not acknowledge a closed page', (
    tester,
  ) async {
    injector.registerSingleton<SettingsBox>(
      MemorySettings()..lastKnownVersion = 'previous',
    );
    final gate = Completer<void>();
    var packageRequests = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(packageChannel, (_) async {
          packageRequests++;
          await gate.future;
          return {
            'appName': 'Test',
            'packageName': 'test.content',
            'version': 'next',
            'buildNumber': '1',
          };
        });
    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold(body: Text('Content page'));
          },
        ),
      ),
    );
    Object? error;
    final pending = ChangelogUtils.check(pageContext).catchError(
      (Object value) {
        error = value;
      },
    );
    await tester.pump();
    expect(packageRequests, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(pageContext.mounted, isFalse);
    gate.complete();
    await tester.pumpAndSettle();
    await pending;
    expect(error, isNull);
    expect(SettingsBox().lastKnownVersion, 'previous');
    expect(tester.takeException(), isNull);
  });
}
