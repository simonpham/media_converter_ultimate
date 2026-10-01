import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:converter/converter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcu/theme_adapter.dart';
import 'package:platform_utils/platform_utils.dart' show FileService;
import 'package:sofluffy_ui/sofluffy_ui.dart';

import 'support/conversion_test_support.dart';

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
            data: theme.copyWith(brightness: isDark ? .dark : .light),
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

  testWidgets('selecting a preset updates settings and selection semantics', (
    tester,
  ) async {
    await showPicker(tester);
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
    expect(find.text('Quick presets'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid next taps move the wizard only one step', (tester) async {
    injector.registerSingleton<FileService>(TestMediaFiles());
    await showPicker(
      tester,
      content: JobMaker(
        formatConfigModel: model.formatConfigModel,
        translations: (jsonDecode(
          File('${findRepository().path}/apps/mcu/assets/configs/l10n/en.json')
              .readAsStringSync(),
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
    expect(find.text('Quick presets'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('trim editor validates inline and can return to the full track', (
    tester,
  ) async {
    await model.applyPreset(.musicMp3);
    await showPicker(tester, content: const TrimEditor());
    await tester.tap(find.text('Trim media'));
    await tester.pumpAndSettle();
    expect(model.trimEnabled, isTrue);
    expect(model.selectedPreset, isNull);
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
    await tester.enterText(end, '0:06.5');
    await tester.pumpAndSettle();
    expect(model.trimFailure, isNull);
    expect(model.selectedTrim?.arguments, ['-ss', '5.000', '-t', '1.500']);
    await tester.tap(find.text('Trim media'));
    await tester.pumpAndSettle();
    expect(model.selectedTrim, isNull);
    expect(find.byType(EditableText), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview summary shows codec, quality, and the selected trim', (
    tester,
  ) async {
    await model.applyPreset(.musicMp3);
    model.setTrimEnabled(true);
    model.setTrimStartText('0:02');
    model.setTrimEndText('0:04.25');
    await showPicker(tester, content: const ConversionSummary());
    expect(find.text('Conversion summary'), findsOneWidget);
    expect(find.text('Custom settings'), findsOneWidget);
    expect(find.textContaining('320'), findsOneWidget);
    expect(find.text('Trim media: 00:02 – 00:04.250'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
    'trim controls wrap on a narrow screen with large translated text',
    (tester) async {
      await model.applyPreset(.musicMp3);
      model.setTrimEnabled(true);
      model.setTrimStartText('0:05');
      model.setTrimEndText('0:03');
      await showPicker(
        tester,
        scale: 2,
        locale: const Locale('de'),
        size: const Size(320, 640),
        content: Builder(
          builder: (context) => JobMakerSteps.customizeConfigs.build(context),
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('customizer offers only presets for the selected format', (
    tester,
  ) async {
    await model.applyPreset(.musicMp3);
    await showPicker(
      tester,
      content: Builder(
        builder: (context) => JobMakerSteps.customizeConfigs.build(context),
      ),
    );
    expect(find.text('MP3 music'), findsOneWidget);
    expect(find.text('Compatible video'), findsNothing);
    expect(find.text('Lossless audio'), findsNothing);
    await tester.tap(find.text('MP3 music'));
    await tester.pumpAndSettle();
    expect(model.selectedPreset, ConversionPreset.musicMp3);
    expect(model.selectedFormatEntry?.name, 'mp3');
    expect(tester.takeException(), isNull);
  });
}

class _PickerFiles extends TestMediaFiles {
  int pickCount = 0;

  @override
  Future<List<File>> chooseFiles(dynamic context) async {
    pickCount++;
    return [];
  }
}
