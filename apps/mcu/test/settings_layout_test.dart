import 'package:converter/converter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

import 'support/conversion_test_support.dart';

void main() {
  late _Settings settings;

  setUp(() {
    settings = _Settings();
    injector.registerSingleton<SettingsBox>(settings);
    installShippedAssetHandler();
  });

  tearDown(() async {
    clearShippedAssetHandler();
    await injector.reset();
    settings.changes.dispose();
  });

  Future<void> showSettings(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ScreenSizeScope(
        child: FluffyTheme(
          data: FluffyThemeData.fallback(),
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SettingsPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final width in <double>[390, 700]) {
    testWidgets('settings stay a single list at ${width.toInt()}px wide', (
      tester,
    ) async {
      await showSettings(tester, width);
      expect(find.byType(VerticalDivider), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in <double>[1000, 1300, 1700]) {
    testWidgets('settings open child pages in place at ${width.toInt()}px', (
      tester,
    ) async {
      await showSettings(tester, width);
      final l10n = tester.element(find.byType(SettingsPage)).l10n;
      expect(find.byType(VerticalDivider), findsOneWidget);
      expect(
        find.byType(DefaultOutputFormatSettingsChild, skipOffstage: false),
        findsNothing,
      );
      expect(find.text(l10n.conversionDefaultOutputFormat), findsNWidgets(2));

      await tester.ensureVisible(find.text(l10n.displayAppTheme));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.displayAppTheme));
      await tester.pumpAndSettle();
      expect(find.text(l10n.displayAppTheme), findsNWidgets(2));

      await tester.tap(find.text(l10n.appThemeDark));
      await tester.pumpAndSettle();
      expect(settings.appTheme, ThemeMode.dark);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('saving an embedded child page keeps settings open', (
    tester,
  ) async {
    await showSettings(tester, 1300);
    final context = tester.element(find.byType(SettingsPage));
    final label = SettingsPageItem.threadCount.getLabel(context);
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
    expect(find.text(label), findsNWidgets(2));

    await tester.drag(find.byType(Slider), const Offset(200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text(context.l10n.save));
    await tester.pumpAndSettle();
    expect(settings.threadCount, isNot(0));
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.text(label), findsNWidgets(2));
    expect(find.text(context.l10n.save), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
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
