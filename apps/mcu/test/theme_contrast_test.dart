import 'dart:convert';
import 'dart:io';

import 'package:converter/converter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcu/theme_adapter.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

import 'support/conversion_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(installShippedAssetHandler);
  tearDown(clearShippedAssetHandler);
  final brand = FluffyThemeData.fromJson(
    jsonDecode(
      File.fromUri(
        findRepository().uri.resolve('apps/mcu/assets/themes/default.json'),
      ).readAsStringSync(),
    ),
  );

  for (final isDark in [false, true]) {
    final mode = isDark ? 'dark' : 'light';
    test('$mode accents and secondary text remain readable on surfaces', () {
      final theme = brand.getTheme(isDark: isDark);
      final scheme = theme.colorScheme;
      for (final background in [
        theme.scaffoldBackgroundColor,
        theme.cardColor,
        theme.dialogTheme.backgroundColor!,
      ]) {
        for (final (label, foreground) in [
          ('primary', scheme.primary),
          ('secondary', scheme.secondary),
          ('error', scheme.error),
          ('secondary text', scheme.onSurfaceVariant),
          ('hint text', theme.hintColor),
        ]) {
          expect(
            contrastRatio(foreground, background),
            greaterThanOrEqualTo(4.5),
            reason: '$mode $label must remain readable on each surface',
          );
        }
      }
    });

    test('$mode filled controls retain readable foregrounds', () {
      final theme = brand.getTheme(isDark: isDark);
      final scheme = theme.colorScheme;
      for (final (foreground, background) in [
        (scheme.onPrimary, scheme.primary),
        (scheme.onSecondary, scheme.secondary),
        (scheme.onError, scheme.error),
        (
          theme.floatingActionButtonTheme.foregroundColor!,
          theme.floatingActionButtonTheme.backgroundColor!,
        ),
      ]) {
        expect(
          contrastRatio(foreground, background),
          greaterThanOrEqualTo(4.5),
        );
      }
    });

    testWidgets('$mode design-system controls use the same readable accents', (
      tester,
    ) async {
      final material = brand.getTheme(isDark: isDark);
      final fluffy = brand.getFluffyTheme(isDark: isDark);
      late BuildContext buttonContext;
      await tester.pumpWidget(
        MaterialApp(
          theme: material,
          home: FluffyTheme(
            data: fluffy,
            child: Builder(
              builder: (context) {
                buttonContext = context;
                return const Scaffold(
                  body: Button(variant: .primary, label: 'Convert'),
                );
              },
            ),
          ),
        ),
      );
      expect(fluffy.brightness, material.brightness);
      expect(fluffy.colors.primary, material.colorScheme.primary);
      expect(fluffy.colors.secondary, material.colorScheme.secondary);
      final label = tester.widget<Text>(find.text('Convert'));
      expect(
        contrastRatio(label.style!.color!, fluffy.colors.primary),
        greaterThanOrEqualTo(4.5),
      );
      for (final variant in ButtonVariant.values) {
        expect(
          contrastRatio(
            variant.getForegroundColor(buttonContext, .normal, null)!,
            variant.getBackgroundColor(buttonContext, .normal, null)!,
          ),
          greaterThanOrEqualTo(4.5),
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('$mode job labels and format badges remain legible', (
      tester,
    ) async {
      final theme = brand.getTheme(isDark: isDark);
      for (final status in JobStatus.values) {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: theme,
            home: FluffyTheme(
              data: brand.getFluffyTheme(isDark: isDark),
              child: Scaffold(
                body: JobItem(
                  ConvertJob(
                    id: 'contrast-$status',
                    inputFilePath: '/source.wav',
                    outputFileName: 'output.mp4',
                    outputExtension: 'mp4',
                    outputDirectoryPath: '/output',
                    command: '[]',
                    convertedFilePath: '/temp/output.mp4',
                    status: status,
                    progress: 500,
                    duration: 1000,
                    createdAt: DateTime(2026),
                    updatedAt: DateTime(2026),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final statusText = tester.widget<Text>(
          find.byWidgetPredicate(
            (widget) => widget is Text && widget.textSpan != null,
          ),
        );
        final statusSpan =
            (statusText.textSpan! as TextSpan).children!.single as TextSpan;
        final input = tester.widget<Text>(find.text('Input: source.wav'));
        for (final foreground in [
          statusText.style!.color!,
          statusSpan.style!.color!,
          input.style!.color!,
        ]) {
          expect(
            contrastRatio(foreground, theme.cardColor),
            greaterThanOrEqualTo(4.5),
            reason: '$mode $status labels must remain readable',
          );
        }
        final badge = tester.widget<Container>(
          find.descendant(
            of: find.byType(JobFileFormatIndicator),
            matching: find.byType(Container),
          ),
        );
        final extension = tester.widget<Text>(find.text('MP4'));
        expect(
          contrastRatio(
            extension.style!.color!,
            (badge.decoration! as ShapeDecoration).color!,
          ),
          greaterThanOrEqualTo(4.5),
          reason: '$mode $status format badge must remain readable',
        );
        if (status.isProcessing) {
          final progress = tester.widget<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          );
          expect(
            contrastRatio(
              progress.color!,
              Color.alphaBlend(progress.backgroundColor!, theme.cardColor),
            ),
            greaterThanOrEqualTo(3),
          );
        }
        expect(tester.takeException(), isNull);
      }
    });
  }
}

double contrastRatio(Color first, Color second) {
  final a = first.computeLuminance();
  final b = second.computeLuminance();
  return a >= b ? (a + 0.05) / (b + 0.05) : (b + 0.05) / (a + 0.05);
}
