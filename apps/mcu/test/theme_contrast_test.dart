import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcu/theme_adapter.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

import 'support/conversion_test_support.dart';

void main() {
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
  }
}

double contrastRatio(Color first, Color second) {
  final a = first.computeLuminance();
  final b = second.computeLuminance();
  return a >= b ? (a + 0.05) / (b + 0.05) : (b + 0.05) / (a + 0.05);
}
