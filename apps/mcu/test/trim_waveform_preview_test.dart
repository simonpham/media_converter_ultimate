import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:converter/converter.dart';
import 'package:converter/features/job_maker/ui/widgets/trim_waveform_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcu/theme_adapter.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

import 'support/conversion_test_support.dart';

void main() {
  late FluffyThemeData theme;

  setUp(() {
    theme = FluffyThemeData.fromJson(
      jsonDecode(
        File('${findRepository().path}/apps/mcu/assets/themes/default.json')
            .readAsStringSync(),
      ),
    );
  });

  Widget preview(
    ValueNotifier<(String?, bool)> state, {
    bool reducedMotion = false,
  }) => MaterialApp(
    theme: theme.getTheme(isDark: true),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => FluffyTheme(
      data: theme.getFluffyTheme(isDark: true),
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
        child: child!,
      ),
    ),
    home: Center(
      child: SizedBox(
        width: 320,
        height: 48,
        child: ValueListenableBuilder<(String?, bool)>(
          valueListenable: state,
          builder: (_, value, _) => TrimWaveformPreview(
            path: value.$1,
            loading: value.$2,
          ),
        ),
      ),
    ),
  );

  testWidgets('waveform loading fades to decoded image without resizing', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync(
      'trim_waveform_test_',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final path = '${directory.path}/wave.png';
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 16, 8), Paint());
      final picture = recorder.endRecording();
      final image = await picture.toImage(16, 8);
      final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await File(path).writeAsBytes(data.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    });
    final state = ValueNotifier<(String?, bool)>((null, true));
    addTearDown(state.dispose);
    await tester.pumpWidget(preview(state));
    await tester.pump(const Duration(milliseconds: 300));
    final bounds = tester.getSize(find.byType(TrimWaveformPreview));
    expect(find.byKey(const ValueKey('trim-waveform-loading')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.binding.hasScheduledFrame, isTrue);
    state.value = (path, false);
    await tester.pump();
    for (
      var attempt = 0;
      attempt < 10 && find.byType(ImageView).evaluate().isEmpty;
      attempt++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(find.byType(ImageView), findsOneWidget);
    expect(find.byKey(const ValueKey('trim-waveform-loading')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('trim-waveform-loading')), findsNothing);
    expect(tester.getSize(find.byType(TrimWaveformPreview)), bounds);
    expect(tester.getSize(find.byType(ImageView)), bounds);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reduced motion keeps loading static and disposal stops animation',
    (tester) async {
      final state = ValueNotifier<(String?, bool)>((null, true));
      addTearDown(state.dispose);
      await tester.pumpWidget(preview(state, reducedMotion: true));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('trim-waveform-loading')),
        findsOneWidget,
      );
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pumpWidget(preview(state));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
