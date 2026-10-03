import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:converter/converter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcu/theme_adapter.dart';
import 'package:platform_utils/platform_utils.dart'
    show FileService, MediaPreviewSession, PreviewMediaInfo;
import 'package:sofluffy_ui/sofluffy_ui.dart';

import 'support/conversion_test_support.dart';
import 'support/preview_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late JobMakerViewModel model;
  late FluffyThemeData theme;

  setUpAll(() async {
    final fontPath = Platform.environment['MCU_CAPTURE_FONT'];
    if (fontPath != null) {
      final loader = FontLoader('Roboto');
      loader.addFont(
        Future.value(ByteData.sublistView(File(fontPath).readAsBytesSync())),
      );
      await loader.load();
    }
  });

  setUp(() {
    injector.registerSingleton<SettingsBox>(MemorySettings());
    injector.registerSingleton<JobConfigurationData>(MemoryConfigurations());
    installShippedAssetHandler();
    model = JobMakerViewModel(
      formatConfigModel: loadShippedFormats(),
      translations: (jsonDecode(
        File('${findRepository().path}/apps/mcu/assets/configs/l10n/en.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>).cast<String, String>(),
    );
    theme = FluffyThemeData.fromJson(
      jsonDecode(
        File('${findRepository().path}/apps/mcu/assets/themes/default.json')
            .readAsStringSync(),
      ),
    );
  });

  tearDown(() async {
    model.dispose();
    clearShippedAssetHandler();
    await injector.reset();
  });

  Future<void> showPicker(
    WidgetTester tester, {
    bool isDark = false,
    double scale = 1,
    Locale locale = const Locale('en'),
    Size size = const Size(390, 844),
    GlobalKey? screenshotKey,
    Widget? content,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider<JobMakerViewModel>.value(
        value: model,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: theme.getTheme(isDark: isDark),
          builder: (context, child) => FluffyTheme(
            data: theme.getFluffyTheme(isDark: isDark),
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: .linear(scale)),
              child: child!,
            ),
          ),
          home: RepaintBoundary(
            key: screenshotKey,
            child: Scaffold(
              appBar: AppBar(
                title: Builder(
                  builder: (context) => Text(
                    content == null
                        ? context.l10n.chooseOutputFormat
                        : context.l10n.customizeConfigs,
                  ),
                ),
              ),
              body: content ?? const JobMakerOutputFormatPicker(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder buttonWithTooltip(String label) => find.byWidgetPredicate(
    (widget) => widget is Button && widget.tooltip == label,
  );

  Widget presetCards() => SingleChildScrollView(
    padding: .all(Spacing.d16),
    child: Consumer<JobMakerViewModel>(
      builder: (context, model, _) => ConversionPresetPicker(
        presets: model.availablePresets,
        selectedPreset: model.selectedPreset,
        onSelected: (preset) {
          if (preset != model.selectedPreset) {
            unawaited(model.applyPreset(preset));
          }
        },
      ),
    ),
  );

  testWidgets(
    'a vanished file renders its cached icon without filesystem access',
    (tester) async {
      await showPicker(
        tester,
        content: FileItem(
          File('/missing/vanished.wav'),
          contentType: .audio,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<FileIcon>(find.byType(FileIcon)).type,
        FileContentType.audio,
      );
      expect(find.text('vanished.wav'), findsOneWidget);
    },
  );

  testWidgets('Add Files semantics stay within the actual button', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final files = _PickerFiles();
      injector.registerSingleton<FileService>(files);
      await showPicker(tester, content: const JobMakerFilePicker());
      final button = find.widgetWithText(Button, 'Add Files');
      final node = tester.getSemantics(find.bySemanticsLabel('Add Files'));
      expect(
        node,
        isSemantics(label: 'Add Files', isButton: true, hasTapAction: true),
      );
      expect(
        node.rect.height,
        lessThanOrEqualTo(tester.getSize(button).height),
      );
      await tester.tap(find.bySemanticsLabel('Add Files'));
      await tester.pumpAndSettle();
      expect(files.pickCount, 1);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('swiping a file row scrolls without reordering the batch', (
    tester,
  ) async {
    injector.registerSingleton<FileService>(_PickerFiles());
    await model.addFiles([
      for (var index = 0; index < 40; index++) File('/input/file-$index.wav'),
    ]);
    final original = model.selectedFiles.map((file) => file.path).toList();
    await showPicker(tester, content: const JobMakerFilePicker());
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    await tester.drag(find.text('file-5.wav'), const Offset(0, -250));
    await tester.pumpAndSettle();
    expect(scroll.position.pixels, greaterThan(100));
    expect(model.selectedFiles.map((file) => file.path), original);
    expect(tester.takeException(), isNull);
  });

  testWidgets('drag handle reorders files and remove still works', (
    tester,
  ) async {
    injector.registerSingleton<FileService>(_PickerFiles());
    await model.addFiles([
      for (var index = 0; index < 4; index++) File('/input/file-$index.wav'),
    ]);
    await showPicker(tester, content: const JobMakerFilePicker());
    final handle = find.byWidgetPredicate(
      (widget) => widget is ReorderableDragStartListener && widget.index == 0,
    );
    final target = Offset(
      tester.getCenter(handle).dx,
      tester.getBottomLeft(find.byKey(const ValueKey('/input/file-3.wav'))).dy +
          30,
    );
    final origin = tester.getCenter(handle);
    await tester.timedDragFrom(
      origin,
      target - origin,
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();
    expect(model.selectedFiles.map((file) => file.uri.pathSegments.last), [
      'file-1.wav',
      'file-2.wav',
      'file-3.wav',
      'file-0.wav',
    ]);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('/input/file-0.wav')),
        matching: find.byType(Button),
      ),
    );
    await tester.pumpAndSettle();
    expect(model.selectedFiles.map((file) => file.uri.pathSegments.last), [
      'file-1.wav',
      'file-2.wav',
      'file-3.wav',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('batch controls fit long names and large German text', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      injector.registerSingleton<FileService>(_PickerFiles());
      await model.addFiles([
        for (var index = 0; index < 20; index++)
          File('/input/A long recording with a descriptive title $index.wav'),
      ]);
      await showPicker(
        tester,
        content: const JobMakerFilePicker(),
        locale: const Locale('de'),
        scale: 2,
        size: const Size(320, 640),
      );
      final handle = find.byWidgetPredicate(
        (widget) => widget is ReorderableDragStartListener && widget.index == 0,
      );
      expect(handle, findsOneWidget);
      expect(tester.getSemantics(handle).tooltip, 'Zum Umordnen ziehen');
      final row = tester.getRect(
        find.byKey(
          const ValueKey(
            '/input/A long recording with a descriptive title 0.wav',
          ),
        ),
      );
      final handleBounds = tester.getRect(handle);
      expect(row.contains(handleBounds.topLeft), isTrue);
      expect(row.contains(handleBounds.bottomRight), isTrue);
      final remove = find.bySemanticsLabel('Aus Auswahl entfernen').first;
      final removeBounds = tester.getRect(remove);
      expect(row.contains(removeBounds.topLeft), isTrue);
      expect(row.contains(removeBounds.bottomRight), isTrue);
      expect(handleBounds.overlaps(removeBounds), isFalse);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(model.selectedFiles, hasLength(19));
      final remainingPaths = model.selectedFiles
          .map((file) => file.path)
          .toList();
      final scroll = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      await tester.drag(
        find.text('A long recording with a descriptive title 1.wav'),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      expect(scroll.position.pixels, greaterThan(0));
      expect(model.selectedFiles.map((file) => file.path), remainingPaths);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('excluded-file notice remains usable with large German text', (
    tester,
  ) async {
    injector.registerSingleton<FileService>(_MixedPickerFiles());
    await model.addFiles([File('/input/notes.txt'), File('/input/song.wav')]);
    await showPicker(
      tester,
      content: const JobMakerFilePicker(),
      locale: const Locale('de'),
      scale: 2,
      size: const Size(320, 640),
    );
    expect(model.excludedFiles, hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.widgetWithText(Button, 'Ignorieren'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Button, 'Ignorieren'));
    await tester.pumpAndSettle();
    expect(model.excludedFiles, isEmpty);
    expect(model.selectedFiles.single.path, '/input/song.wav');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'presets toggle grid/list with aligned headers and format badges',
    (tester) async {
      await showPicker(tester, content: presetCards());
      expect(buttonWithTooltip('Show list'), findsOneWidget);
      final first = find.byKey(const ValueKey('preset-format-compatibleVideo'));
      final second = find.byKey(const ValueKey('preset-format-smallerVideo'));
      expect(tester.getTopLeft(first).dy, tester.getTopLeft(second).dy);
      expect(
        tester.getTopLeft(find.text('Quick presets')).dx,
        tester
            .getTopLeft(
              find.text('Choose a task, then fine-tune the settings.'),
            )
            .dx,
      );
      await tester.tap(find.byKey(const ValueKey('preset-layout-toggle')));
      await tester.pumpAndSettle();
      expect(buttonWithTooltip('Show grid'), findsOneWidget);
      for (final preset in ConversionPreset.values) {
        expect(
          tester
              .getTopLeft(find.byKey(ValueKey('preset-format-${preset.name}')))
              .dy,
          tester.getTopLeft(first).dy,
        );
      }
      await tester.tap(find.byKey(const ValueKey('preset-layout-toggle')));
      await tester.pumpAndSettle();
      expect(buttonWithTooltip('Show list'), findsOneWidget);
      await tester.tap(find.text('Compatible video'));
      await tester.pumpAndSettle();
      await model.applyPreset(.highQualityVideo);
      await tester.pumpAndSettle();
      expect(model.selectedValues['configs.mp4.crf.x264'], '18');
      expect(find.widgetWithText(Button, 'Custom settings'), findsNothing);
      await tester.tap(
        find.descendant(
          of: find.byType(ConversionPresetPicker),
          matching: find.text('High-quality video'),
        ),
      );
      await tester.pumpAndSettle();
      expect(model.selectedPreset, ConversionPreset.highQualityVideo);
      expect(model.selectedValues['configs.mp4.crf.x264'], '18');
      expect(find.text('Load Previous Configs'), findsNothing);
      expect(find.text('Reset To Default'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('selecting a preset updates settings and selection semantics', (
    tester,
  ) async {
    await showPicker(tester, content: presetCards());
    expect(find.text('Quick presets'), findsOneWidget);
    await tester.tap(find.text('Compatible video'));
    await tester.pumpAndSettle();
    expect(model.selectedPreset, ConversionPreset.compatibleVideo);
    expect(model.selectedValues['configs.mp4.crf.x264'], '23');
    final selection = find
        .ancestor(
          of: find.text('Compatible video'),
          matching: find.byType(Semantics),
        )
        .evaluate()
        .map((element) => (element.widget as Semantics).properties.selected);
    expect(selection, contains(true));
    expect(tester.takeException(), isNull);
  });

  testWidgets('format step opens chooser and cancel preserves settings', (
    tester,
  ) async {
    await model.applyPreset(.highQualityVideo);
    final settings = {...model.selectedValues};
    await showPicker(tester);
    expect(find.byType(ConversionPresetPicker), findsNothing);
    await tester.tap(find.byKey(const ValueKey('choose-conversion-preset')));
    await tester.pumpAndSettle();
    expect(find.byType(ConversionPresetPicker), findsOneWidget);
    expect(find.byKey(const ValueKey('preset-layout-toggle')), findsNothing);
    expect(
      find.descendant(
        of: find.byType(ConversionPresetPicker),
        matching: find.text('High-quality video'),
      ),
      findsOneWidget,
    );
    expect(buttonWithTooltip('Cancel'), findsNothing);
    await tester.tapAt(Offset(Spacing.d8, Spacing.d8));
    await tester.pumpAndSettle();
    expect(model.selectedPreset, ConversionPreset.highQualityVideo);
    expect(model.selectedValues, settings);
    await tester.tap(find.byKey(const ValueKey('choose-conversion-preset')));
    await tester.pumpAndSettle();
    final sheet = tester.getRect(find.byType(BottomSheet));
    await tester.dragFrom(
      Offset(sheet.center.dx, sheet.top + Spacing.d16),
      Offset(0, sheet.height),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ConversionPresetPicker), findsNothing);
    expect(model.selectedPreset, ConversionPreset.highQualityVideo);
    expect(model.selectedValues, settings);
    await tester.tap(find.byKey(const ValueKey('choose-conversion-preset')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(ConversionPresetPicker),
        matching: find.text('High-quality video'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ConversionPresetPicker), findsNothing);
    expect(model.selectedPreset, ConversionPreset.highQualityVideo);
    expect(model.selectedValues, settings);
    await tester.tap(find.byKey(const ValueKey('choose-conversion-preset')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('deselect-conversion-preset')));
    await tester.pumpAndSettle();
    expect(model.selectedPreset, isNull);
    expect(model.selectedValues['configs.mp4.crf.x264'], '23');
    expect(find.text('Choose preset'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'home cards report shortcuts and collapse without changing a draft',
    (tester) async {
      final selected = <ConversionPreset>[];
      await showPicker(
        tester,
        content: SingleChildScrollView(
          child: HomePresetShortcuts(onSelected: selected.add),
        ),
      );
      expect(find.text('Quick convert'), findsOneWidget);
      expect(find.text('Quick presets'), findsNothing);
      expect(
        find.text('Balanced quality and broad playback support.'),
        findsNothing,
      );
      await tester.tap(find.text('Compatible video'));
      await tester.pumpAndSettle();
      expect(selected, [ConversionPreset.compatibleVideo]);
      expect(model.selectedPreset, isNull);
      await tester.tap(find.byKey(const ValueKey('home-presets-toggle')));
      await tester.pumpAndSettle();
      expect(find.byType(ConversionPresetPicker), findsNothing);
      expect(buttonWithTooltip('Show quick presets'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('home-presets-toggle')));
      await tester.pumpAndSettle();
      expect(find.text('Compatible video'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'preset shortcut skips format and preserves trims through changes',
    (tester) async {
      injector.registerSingleton<FileService>(TestMediaFiles());
      await showPicker(
        tester,
        content: JobMaker(
          formatConfigModel: model.formatConfigModel,
          translations: model.translations,
          initialPreset: .musicMp3,
        ),
      );
      final wizard = tester
          .element(find.byType(JobMakerFilePicker))
          .read<JobMakerViewModel>();
      expect(wizard.selectedPreset, ConversionPreset.musicMp3);
      expect(
        tester.widget<StepperWidget>(find.byType(StepperWidget)).stepCount,
        3,
      );
      final directory = Directory.systemTemp.createTempSync('mcu-shortcut-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final source = File('${directory.path}/song.wav')
        ..writeAsBytesSync(utf8.encode('RIFF0000WAVE'));
      await wizard.addFiles([source]);
      const trim = ConversionTrim(
        start: Duration(seconds: 1),
        end: Duration(seconds: 3),
      );
      wizard.setFileTrim(
        source.path,
        const FileTrimResult(trim: trim, duration: Duration(seconds: 4)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.byType(JobMakerConfigCustomizer), findsOneWidget);
      expect(find.byType(JobMakerOutputFormatPicker), findsNothing);
      expect(find.byType(ConversionPresetPicker), findsNothing);
      expect(find.text('MP3 music'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('choose-conversion-preset')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.descendant(
          of: find.byType(ConversionPresetPicker),
          matching: find.text('Compact audio'),
        ),
      );
      await tester.tap(
        find.descendant(
          of: find.byType(ConversionPresetPicker),
          matching: find.text('Compact audio'),
        ),
      );
      await tester.pumpAndSettle();
      expect(wizard.selectedPreset, ConversionPreset.compactAudio);
      expect(wizard.selectedFormatEntry!.name, 'm4a');
      expect(wizard.selectedFiles.single.path, source.path);
      expect(wizard.trimFor(source.path), trim);
      expect(wizard.outputFileNames[source.path], 'song.m4a');
      await tester.tap(find.byKey(const ValueKey('choose-conversion-preset')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('deselect-conversion-preset')),
      );
      await tester.pumpAndSettle();
      expect(wizard.selectedPreset, isNull);
      expect(wizard.trimFor(source.path), trim);
      expect(find.text('Choose preset'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.byType(JobMakerPreview), findsOneWidget);
      expect(
        tester.widget<StepperWidget>(find.byType(StepperWidget)).currentStep,
        2,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(JobMakerConfigCustomizer), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(JobMakerFilePicker), findsOneWidget);
      expect(find.byType(JobMakerOutputFormatPicker), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('unsupported shortcut falls back to four steps', (tester) async {
    await showPicker(
      tester,
      content: JobMaker(
        formatConfigModel: FormatConfigModel(
          formats: model.formatConfigModel.formats
              .where((format) => format.name != 'mp4')
              .toList(),
          uiGradients: model.formatConfigModel.uiGradients,
        ),
        translations: model.translations,
        initialPreset: .compatibleVideo,
      ),
    );
    expect(
      tester.widget<StepperWidget>(find.byType(StepperWidget)).stepCount,
      4,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('search filters format tiles and can recover from no results', (
    tester,
  ) async {
    await showPicker(tester);
    await tester.enterText(find.byType(EditableText), ' .MP3 ');
    await tester.pumpAndSettle();
    expect(find.byType(OutputFormatGridItem), findsOneWidget);
    expect(find.text('Quick presets'), findsNothing);
    await tester.tap(find.text('MP3'));
    await tester.pumpAndSettle();
    expect(model.selectedFormatEntry?.name, 'mp3');
    await tester.enterText(find.byType(EditableText), 'nothing');
    await tester.pumpAndSettle();
    expect(find.text('No matching formats.'), findsOneWidget);
    await tester.enterText(find.byType(EditableText), '');
    await tester.pumpAndSettle();
    expect(find.text('Choose preset'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'rapid Next moves one step and subsequent Next dismisses search',
    (tester) async {
      injector.registerSingleton<FileService>(TestMediaFiles());
      await showPicker(
        tester,
        content: JobMaker(
          formatConfigModel: model.formatConfigModel,
          translations: (jsonDecode(
            File(
              '${findRepository().path}/apps/mcu/assets/configs/l10n/en.json',
            ).readAsStringSync(),
          ) as Map<String, dynamic>).cast<String, String>(),
        ),
      );
      final wizard = tester
          .element(find.byType(JobMakerFilePicker))
          .read<JobMakerViewModel>();
      final inputDirectory = Directory.systemTemp.createTempSync('mcu-wizard-');
      addTearDown(() => inputDirectory.deleteSync(recursive: true));
      final source = File('${inputDirectory.path}/song.wav')
        ..writeAsBytesSync(utf8.encode('RIFF0000WAVE'));
      await wizard.addFiles([source]);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.byType(JobMakerOutputFormatPicker), findsOneWidget);
      expect(find.byType(JobMakerConfigCustomizer), findsNothing);
      expect(find.text('Choose preset'), findsOneWidget);
      await wizard.applyPreset(.compatibleVideo);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'MP4');
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.byType(JobMakerConfigCustomizer), findsOneWidget);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(
        FocusManager.instance.primaryFocus?.context?.widget,
        isNot(isA<EditableText>()),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('compact trim keeps precise inputs visible and folds helpers', (
    tester,
  ) async {
    injector.registerFactory<MediaPreviewSession>(_VideoPreview.new);
    await showPicker(
      tester,
      size: const Size(440, 844),
      content: const TrimEditor(
        path: '/movie.mkv',
        initial: ConversionTrim(
          start: Duration(seconds: 1),
          end: Duration(seconds: 3),
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('trim-start')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('trim-end')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('file-trim-apply')).hitTestable(),
      findsOneWidget,
    );
    final transport = tester.getRect(
      find.byKey(const ValueKey('trim-transport')),
    );
    final viewControls = tester.getRect(
      find.byKey(const ValueKey('trim-view-controls')),
    );
    final startInput = tester.getRect(find.byKey(const ValueKey('trim-start')));
    final timeline = tester.getRect(
      find.byKey(const ValueKey('trim-visual-track')),
    );
    expect(transport.top, greaterThan(timeline.bottom));
    expect(transport.center.dy, closeTo(viewControls.center.dy, 1));
    expect(viewControls.left, greaterThan(transport.right));
    expect(startInput.top, greaterThan(transport.bottom));
    expect(
      tester.getRect(find.byKey(const ValueKey('trim-fine-toggle'))).width,
      closeTo(timeline.width, 1),
    );
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('trim-reset')),
        matching: find.byType(AppBar),
      ),
      findsOneWidget,
    );
    final beforeSeek = tester.getRect(
      find.byKey(const ValueKey('trim-target-cursor')),
    );
    tester
        .element(find.byKey(const ValueKey('trim-visual-track')))
        .read<TrimTimelineViewModel>()
        .seek(5125);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const ValueKey('trim-target-cursor'))),
      beforeSeek,
    );
    expect(find.text('+0.1 s'), findsNothing);
    expect(find.text('Set start here'), findsNothing);
    expect(find.text('Set end here'), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('trim-fine-toggle')));
    await tester.tap(find.byKey(const ValueKey('trim-fine-toggle')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('trim-fine-target-end')),
    );
    await tester.tap(find.byKey(const ValueKey('trim-fine-target-end')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('+0.1 s'));
    await tester.tap(find.text('+0.1 s'));
    await tester.pumpAndSettle();
    final field = find.descendant(
      of: find.byKey(const ValueKey('trim-end')),
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(field).controller.text, '00:03.100');
    expect(model.trimFor('/movie.mkv'), isNull);
    await tester.ensureVisible(find.byKey(const ValueKey('trim-fine-toggle')));
    await tester.tap(find.byKey(const ValueKey('trim-fine-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('+0.1 s'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'trim controls keep groups intact on narrow screens at ${scale}x',
      (tester) async {
        injector.registerFactory<MediaPreviewSession>(_VideoPreview.new);
        await showPicker(
          tester,
          scale: scale,
          locale: const Locale('de'),
          size: const Size(320, 844),
          content: const TrimEditor(path: '/movie.mkv'),
        );
        final transport = tester.getRect(
          find.byKey(const ValueKey('trim-transport')),
        );
        final viewControls = tester.getRect(
          find.byKey(const ValueKey('trim-view-controls')),
        );
        expect(viewControls.top, greaterThanOrEqualTo(transport.bottom));
        expect(viewControls.left, closeTo(transport.left, 1));
        for (final key in [
          'trim-playback',
          'trim-target-cursor',
          'trim-overview',
          'trim-reset',
        ]) {
          final bounds = tester.getSize(find.byKey(ValueKey(key)));
          expect(bounds.width, greaterThanOrEqualTo(48));
          expect(bounds.height, greaterThanOrEqualTo(48));
        }
        await tester.ensureVisible(
          find.byKey(const ValueKey('trim-fine-toggle')),
        );
        await tester.tap(find.byKey(const ValueKey('trim-fine-toggle')));
        await tester.pumpAndSettle();
        final back = tester.getRect(find.text('−0.1 s'));
        final forward = tester.getRect(find.text('+0.1 s'));
        expect(back.center.dy, closeTo(forward.center.dy, 1));
        expect(back.right, lessThan(forward.left));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('preset footer stays reachable with large German text', (
    tester,
  ) async {
    await model.applyPreset(.highQualityVideo);
    await showPicker(
      tester,
      scale: 2,
      locale: const Locale('de'),
      size: const Size(320, 640),
    );
    await tester.tap(find.byKey(const ValueKey('choose-conversion-preset')));
    await tester.pumpAndSettle();
    final footer = find.byKey(const ValueKey('deselect-conversion-preset'));
    expect(footer.hitTestable(), findsOneWidget);
    await tester.tap(footer);
    await tester.pumpAndSettle();
    expect(model.selectedPreset, isNull);
    expect(model.selectedValues['configs.mp4.crf.x264'], '23');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'trim handles, range dragging and precise fields share one draft',
    (tester) async {
      injector.registerFactory<MediaPreviewSession>(TestPreviewSession.new);
      await showPicker(
        tester,
        content: const TrimEditor(
          path: '/song.wav',
          initial: ConversionTrim(
            start: Duration(seconds: 2),
            end: Duration(seconds: 6),
          ),
        ),
      );
      final visual = find.byKey(const ValueKey('trim-visual-track'));
      await tester.ensureVisible(visual);
      final timeline = tester.element(visual).read<TrimTimelineViewModel>();
      var track = tester.getRect(visual);
      final usable = track.width - Spacing.d48;
      await tester.dragFrom(
        Offset(track.left + Spacing.d24 + usable * 0.2, track.center.dy),
        Offset(usable * 0.1, 0),
      );
      await tester.pumpAndSettle();
      expect(timeline.start, closeTo(3000, 50));
      expect(timeline.end, 6000);
      final length = timeline.end - timeline.start;
      track = tester.getRect(visual);
      await tester.dragFrom(
        Offset(track.left + Spacing.d24 + usable * 0.45, track.center.dy),
        Offset(usable * 0.1, 0),
      );
      await tester.pumpAndSettle();
      expect(timeline.start, closeTo(4000, 50));
      expect(timeline.end - timeline.start, length);
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('trim-start')),
          matching: find.byType(EditableText),
        ),
        '0:02.125',
      );
      await tester.pumpAndSettle();
      expect(timeline.start, 2125);
      await tester.ensureVisible(
        find.byKey(const ValueKey('trim-fine-toggle')),
      );
      await tester.tap(find.byKey(const ValueKey('trim-fine-toggle')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('trim-fine-target-end')),
      );
      await tester.tap(find.byKey(const ValueKey('trim-fine-target-end')));
      await tester.pumpAndSettle();
      final before = timeline.end;
      await tester.ensureVisible(find.text('+0.1 s'));
      await tester.tap(find.text('+0.1 s'));
      await tester.pumpAndSettle();
      expect(timeline.end, before + 100);
      expect(model.trimFor('/song.wav'), isNull);
      expect(find.byType(RangeSlider), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'file editor validates precise times without changing the batch draft',
    (tester) async {
      injector.registerFactory<MediaPreviewSession>(TestPreviewSession.new);
      await model.applyPreset(.musicMp3);
      await showPicker(tester, content: const TrimEditor(path: '/song.wav'));
      final start = find.descendant(
        of: find.byKey(const ValueKey('trim-start')),
        matching: find.byType(EditableText),
      );
      final end = find.descendant(
        of: find.byKey(const ValueKey('trim-end')),
        matching: find.byType(EditableText),
      );
      await tester.enterText(start, '0:05');
      await tester.enterText(end, '0:03');
      await tester.pumpAndSettle();
      expect(
        find.text('The end time must be after the start time.'),
        findsOneWidget,
      );
      await tester.enterText(end, '0:11');
      await tester.pumpAndSettle();
      expect(
        find.text('The range must be within this file’s duration.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Button>(find.byKey(const ValueKey('file-trim-apply')))
            .enable,
        isFalse,
      );
      await tester.enterText(end, '0:06.5');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Button>(find.byKey(const ValueKey('file-trim-apply')))
            .enable,
        isTrue,
      );
      expect(model.selectedPreset, ConversionPreset.musicMp3);
      expect(model.trimFor('/song.wav'), isNull);
      await tester.ensureVisible(find.byKey(const ValueKey('trim-reset')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('trim-reset')));
      await tester.pumpAndSettle();
      expect(tester.widget<EditableText>(start).controller.text, isEmpty);
      expect(tester.widget<EditableText>(end).controller.text, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'review applies or cancels one file and leaves other ranges unchanged',
    (tester) async {
      injector.registerSingleton<FileService>(TestMediaFiles());
      injector.registerFactory<MediaPreviewSession>(TestPreviewSession.new);
      await model.addFiles([File('/first.wav'), File('/second.wav')]);
      await model.applyPreset(.musicMp3);
      await showPicker(tester, content: const JobMakerPreview());
      Future<void> open(String path) async {
        final button = find.byKey(ValueKey('trim-file-$path'));
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
      }

      Future<void> enterRange(String start, String end) async {
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('trim-start')),
            matching: find.byType(EditableText),
          ),
          start,
        );
        await tester.enterText(
          find.descendant(
            of: find.byKey(const ValueKey('trim-end')),
            matching: find.byType(EditableText),
          ),
          end,
        );
        await tester.pumpAndSettle();
      }

      await open('/first.wav');
      expect(find.text('first.wav'), findsOneWidget);
      await enterRange('0:02', '0:04.25');
      expect(model.trimFor('/first.wav'), isNull);
      await tester.tap(find.byKey(const ValueKey('file-trim-apply')));
      await tester.pumpAndSettle();
      expect(model.trimFor('/first.wav')!.arguments, [
        '-ss',
        '2.000',
        '-t',
        '2.250',
      ]);
      expect(model.trimFor('/second.wav'), isNull);
      expect(model.selectedPreset, ConversionPreset.musicMp3);
      expect(find.text('00:02 – 00:04.250'), findsOneWidget);
      await open('/second.wav');
      await enterRange('0:01', '0:03');
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(model.trimFor('/second.wav'), isNull);
      await open('/first.wav');
      await tester.ensureVisible(find.byKey(const ValueKey('trim-reset')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('trim-reset')));
      await tester.tap(find.byKey(const ValueKey('file-trim-apply')));
      await tester.pumpAndSettle();
      expect(model.trimFor('/first.wav'), isNull);
      expect(find.byKey(const ValueKey('trim-reset')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'preview summary contains shared codecs without a shared trim range',
    (tester) async {
      await model.applyPreset(.musicMp3);
      await showPicker(tester, content: const ConversionSummary());
      expect(find.text('Conversion summary'), findsOneWidget);
      expect(find.text('MP3 music'), findsOneWidget);
      expect(find.textContaining('320'), findsOneWidget);
      expect(find.textContaining('Trim media:'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('output actions expose labels and invoke the matching action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final invoked = <String>[];
      await showPicker(
        tester,
        content: JobItem(
          ConvertJob(
            id: 'output-actions',
            inputFilePath: '/source.wav',
            outputFileName: 'output.m4a',
            outputExtension: 'm4a',
            outputDirectoryPath: '/output',
            command: '[]',
            convertedFilePath: '/temp/output.m4a',
            status: .completed,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
          onRemoveItem: () => invoked.add('Remove from history'),
          onOpenLogs: () => invoked.add('View logs'),
          onShare: () => invoked.add('Share file'),
          onOpenFile: () => invoked.add('Open file'),
          onOpenFolder: () => invoked.add('Open folder'),
          onDelete: () => invoked.add('Delete'),
        ),
      );
      for (final label in [
        'Remove from history',
        'View logs',
        'Share file',
        'Open file',
        'Open folder',
        'Delete',
      ]) {
        expect(
          tester.getSemantics(find.bySemanticsLabel(label)),
          isSemantics(label: label, isButton: true, hasTapAction: true),
        );
        await tester.tap(find.bySemanticsLabel(label));
        await tester.pump();
      }
      expect(invoked, [
        'Remove from history',
        'View logs',
        'Share file',
        'Open file',
        'Open folder',
        'Delete',
      ]);
      expect(find.bySemanticsLabel('Stop'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('preparation Stop captures its execution before startup', (
    tester,
  ) async {
    final manager = _ProcessingJobManager(.preparing);
    addTearDown(manager.dispose);
    await showPicker(
      tester,
      content: ChangeNotifierProvider<JobManagerViewModel>.value(
        value: manager,
        child: const JobManager(),
      ),
    );
    expect(find.text('Stop'), findsOneWidget);
    manager.executionId = 'later-execution';
    await tester.tap(find.text('Stop'));
    await tester.pump();
    expect(manager.stoppedExecutionId, 'preparation-execution');
    expect(manager.stoppedJob?.sessionId, isNull);
    expect(tester.takeException(), isNull);
  });

  for (final status in <JobStatus>[.stopping, .cleaning]) {
    testWidgets('${status.name} job hides Stop until the operation ends', (
      tester,
    ) async {
      final manager = _ProcessingJobManager(status);
      addTearDown(manager.dispose);
      await showPicker(
        tester,
        content: ChangeNotifierProvider<JobManagerViewModel>.value(
          value: manager,
          child: const JobManager(),
        ),
      );
      final context = tester.element(find.byType(JobManager));
      expect(
        find.textContaining(status.getLabel(context), findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Stop'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('output recovery actions fit large German text', (tester) async {
    await showPicker(
      tester,
      locale: const Locale('de'),
      scale: 2,
      size: const Size(320, 844),
      content: JobActionBar(
        onOpenLogs: () {},
        onRenameOutputFile: () {},
        onSelectNewOutputPath: () {},
      ),
    );
    expect(tester.takeException(), isNull);
  });

  for (final locale in [const Locale('en'), const Locale('de')]) {
    testWidgets('home title leaves room for its menu at 2x text ($locale)', (
      tester,
    ) async {
      await showPicker(
        tester,
        locale: locale,
        scale: 2,
        size: const Size(320, 844),
        content: ChangeNotifierProvider<JobManagerViewModel>(
          create: (_) => _EmptyJobManager(),
          child: const JobManager(),
        ),
      );
      final context = tester.element(find.byType(JobManager));
      final title = find.text(context.l10n.jobManager);
      final menu = find.descendant(
        of: find.byType(SliverAppBar),
        matching: find.byType(Button),
      );
      expect(
        tester.getRect(title).right,
        lessThanOrEqualTo(tester.getRect(menu).left),
      );
      await tester.tap(menu);
      await tester.pumpAndSettle();
      expect(find.text(context.l10n.settingsTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('preview includes only enabled audio editing choices', (
    tester,
  ) async {
    await model.applyPreset(.losslessAudio);
    await showPicker(tester, content: const ConversionSummary());
    expect(find.textContaining('Silence removal:'), findsNothing);
    final control = model.availableControls.singleWhere(
      (control) => control.name == 'configs.common.trim_silence',
    );
    model.setSelectedValue(
      control.name,
      jsonEncode([control.options.single.value]),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Silence removal: Shorten quiet gaps (-50 dB)'),
      findsOneWidget,
    );
    model.setSelectedValue(control.name, '[]');
    await tester.pumpAndSettle();
    expect(find.textContaining('Silence removal:'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reopening the picker keeps the search field in sync', (
    tester,
  ) async {
    model.setFormatQuery('.M4A');
    await showPicker(tester);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      '.M4A',
    );
    expect(find.byType(OutputFormatGridItem), findsOneWidget);
    expect(find.text('M4A'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    (
      name: 'light',
      isDark: false,
      scale: 1.0,
      locale: const Locale('en'),
      size: const Size(390, 844),
    ),
    (
      name: 'dark',
      isDark: true,
      scale: 1.0,
      locale: const Locale('en'),
      size: const Size(390, 844),
    ),
    (
      name: 'large-text-de',
      isDark: false,
      scale: 2.0,
      locale: const Locale('de'),
      size: const Size(320, 640),
    ),
    (
      name: 'vi',
      isDark: false,
      scale: 1.0,
      locale: const Locale('vi'),
      size: const Size(390, 844),
    ),
  ]) {
    testWidgets('reusable preset layouts fit ${scenario.name}', (tester) async {
      await showPicker(
        tester,
        isDark: scenario.isDark,
        scale: scenario.scale,
        locale: scenario.locale,
        size: scenario.size,
        content: presetCards(),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('preset-layout-toggle')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
    testWidgets('format picker lays out in ${scenario.name}', (tester) async {
      final key = GlobalKey();
      await showPicker(
        tester,
        isDark: scenario.isDark,
        scale: scenario.scale,
        locale: scenario.locale,
        size: scenario.size,
        screenshotKey: key,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('choose-conversion-preset')));
      await tester.pumpAndSettle();
      expect(find.byType(ConversionPresetPicker), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('preset-layout-toggle')), findsNothing);
      if (Platform.environment['MCU_CAPTURE_WIDGETS'] == '1') {
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final rendered = await boundary.toImage(pixelRatio: 2);
          final data = await rendered.toByteData(
            format: ui.ImageByteFormat.png,
          );
          final directory = Directory('/tmp/mcu-release-screens');
          await directory.create(recursive: true);
          await File('${directory.path}/format-picker-${scenario.name}.png')
              .writeAsBytes(data!.buffer.asUint8List());
          rendered.dispose();
        });
      }
    });
  }

  testWidgets(
    'file trim controls wrap on a narrow screen with large translated text',
    (tester) async {
      await model.applyPreset(.musicMp3);
      injector.registerFactory<MediaPreviewSession>(TestPreviewSession.new);
      await showPicker(
        tester,
        scale: 2,
        locale: const Locale('de'),
        size: const Size(320, 640),
        content: const TrimEditor(path: '/song.wav'),
      );
      expect(tester.takeException(), isNull);
      await showPicker(
        tester,
        scale: 2,
        locale: const Locale('de'),
        size: const Size(320, 640),
        content: OutputFileItem(
          File('/song.wav'),
          index: 1,
          outputFormat: model.selectedFormatEntry!,
          outputFileName: 'song.mp3',
          trim: const ConversionTrim(
            start: Duration(milliseconds: 1250),
            end: Duration(milliseconds: 5500),
          ),
          onTrimPressed: () {},
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'customizer hides presets and retains selection for the summary',
    (
      tester,
    ) async {
      await model.applyPreset(.musicMp3);
      await showPicker(
        tester,
        content: Builder(
          builder: (context) => JobMakerSteps.customizeConfigs.build(context),
        ),
      );
      expect(find.byType(ConversionPresetPicker), findsNothing);
      expect(find.text('Quick presets'), findsNothing);
      expect(find.text('Remember my preferences'), findsOneWidget);
      expect(find.text('MP3 music'), findsNothing);
      expect(find.text('Compatible video'), findsNothing);
      expect(find.text('Lossless audio'), findsNothing);
      expect(model.selectedPreset, ConversionPreset.musicMp3);
      expect(model.selectedFormatEntry?.name, 'mp3');
      await showPicker(tester, content: const ConversionSummary());
      expect(find.text('MP3 music'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _PickerFiles extends TestMediaFiles {
  int pickCount = 0;

  @override
  Future<List<File>> chooseFiles(dynamic context) async {
    pickCount++;
    return [];
  }
}

class _MixedPickerFiles extends _PickerFiles {
  @override
  Future<String?> getFileMimeType(File file) async =>
      file.path.endsWith('.txt') ? 'text/plain' : 'audio/wav';
}

class _EmptyJobManager extends ChangeNotifier implements JobManagerViewModel {
  @override
  final Stream<List<ConvertJob>> pendingJobsStream = const Stream.empty();
  @override
  final Stream<List<ConvertJob>> runningJobsStream = const Stream.empty();
  @override
  final Stream<List<ConvertJob>> completedJobsStream = const Stream.empty();
  @override
  final Stream<List<ConvertJob>> actionRequiredJobsStream =
      const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProcessingJobManager(final JobStatus status) extends _EmptyJobManager {
  String executionId = 'preparation-execution';
  String? stoppedExecutionId;
  ConvertJob? stoppedJob;

  @override
  Stream<List<ConvertJob>> get runningJobsStream => Stream.value([
    ConvertJob(
      id: 'preparation',
      inputFilePath: '/input.wav',
      outputFileName: 'output.m4a',
      outputExtension: 'm4a',
      outputDirectoryPath: '/output',
      command: '[]',
      convertedFilePath: '/temporary/output.m4a',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      status: status,
    ),
  ]);

  @override
  String? activeExecutionId(String jobId) => executionId;

  @override
  Future<void> removeRunningJob(ConvertJob job, {String? executionId}) async {
    stoppedJob = job;
    stoppedExecutionId = executionId;
  }
}

class _VideoPreview extends TestPreviewSession {
  @override
  Future<PreviewMediaInfo> inspect(String path) async => const PreviewMediaInfo(
    Duration(seconds: 10),
    videoIndex: 0,
    audioIndex: 1,
  );
}
