import 'dart:convert';

import 'package:converter/converter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mcu/theme_adapter.dart';
import 'package:platform_utils/platform_utils.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late List<File> sources;
  late List<int> sourceBytes;
  late FluffyThemeData theme;
  late JobMakerViewModel model;

  setUpAll(() async {
    final files = DirectFileService();
    injector.registerSingleton<FileService>(files);
    final preferences = _Preferences();
    injector.registerSingleton<SettingsBox>(preferences);
    injector.registerSingleton<JobConfigurationData>(preferences);
    directory = await (await files.getAppCacheDirectory()).createTemp(
      'batch_ui_qa_',
    );
    final seed = File('${directory.path}/seed.wav');
    final session = await FFmpegKit.executeWithArguments([
      '-f',
      'lavfi',
      '-i',
      'anullsrc=r=8000:cl=mono',
      '-t',
      '0.01',
      seed.path,
    ]);
    expect(ReturnCode.isSuccess(await session.getReturnCode()), isTrue);
    sourceBytes = await seed.readAsBytes();
    sources = [
      for (var index = 0; index < 40; index++)
        await seed.copy('${directory.path}/file-$index.wav'),
    ];
    theme = FluffyThemeData.fromJson(
      jsonDecode(
        await rootBundle.loadString('assets/themes/default.json'),
      ),
    );
  });

  setUp(() {
    model = JobMakerViewModel(
      formatConfigModel: const FormatConfigModel(formats: [], uiGradients: {}),
      translations: const {},
    );
  });

  tearDown(() => model.dispose());
  tearDownAll(() async {
    await directory.delete(recursive: true);
    await injector.reset();
  });

  Future<void> showPicker(WidgetTester tester, {bool largeText = false}) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<JobMakerViewModel>.value(
        value: model,
        child: MaterialApp(
          locale: largeText ? const Locale('de') : const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: theme.getTheme(isDark: false),
          builder: (context, child) => FluffyTheme(
            data: theme.getFluffyTheme(isDark: false),
            child: MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: .linear(largeText ? 2 : 1)),
              child: child!,
            ),
          ),
          home: const Scaffold(body: SafeArea(child: JobMakerFilePicker())),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('batch scroll, handle drag and removal preserve source files', (
    tester,
  ) async {
    await model.addFiles(sources);
    await showPicker(tester);
    final original = model.selectedFiles.map((file) => file.path).toList();
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    await tester.drag(find.text('file-5.wav'), const Offset(0, -250));
    await tester.pumpAndSettle();
    expect(scroll.position.pixels, greaterThan(100));
    expect(model.selectedFiles.map((file) => file.path), original);
    scroll.position.jumpTo(0);
    await tester.pumpAndSettle();
    final handle = find.byWidgetPredicate(
      (widget) => widget is ReorderableDragStartListener && widget.index == 0,
    );
    final origin = tester.getCenter(handle);
    final target = Offset(
      origin.dx,
      tester.getCenter(find.text('file-3.wav')).dy,
    );
    await tester.timedDragFrom(
      origin,
      target - origin,
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();
    expect(model.selectedFiles.take(4).map((file) => file.path), [
      sources[1].path,
      sources[2].path,
      sources[3].path,
      sources[0].path,
    ]);
    await tester.tap(
      find.descendant(
        of: find.byKey(ValueKey(sources.first.path)),
        matching: find.byType(Button),
      ),
    );
    await tester.pumpAndSettle();
    expect(model.selectedFiles, hasLength(39));
    for (final source in sources) {
      expect(await source.exists(), isTrue);
      expect(await source.readAsBytes(), sourceBytes);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('large German exclusion notice scrolls and dismisses safely', (
    tester,
  ) async {
    final excluded = File('${directory.path}/notes.txt')
      ..writeAsStringSync('Owned QA note');
    await model.addFiles([excluded, ...sources]);
    expect(model.excludedFiles, hasLength(1));
    await showPicker(tester, largeText: true);
    final dismiss = find.widgetWithText(Button, 'Ignorieren');
    await tester.ensureVisible(dismiss);
    await tester.pumpAndSettle();
    await tester.tap(dismiss);
    await tester.pumpAndSettle();
    expect(model.excludedFiles, isEmpty);
    expect(model.selectedFiles, hasLength(40));
    expect(await excluded.readAsString(), 'Owned QA note');
    expect(tester.takeException(), isNull);
  });
}

class _Preferences implements SettingsBox, JobConfigurationData {
  final values = <dynamic, dynamic>{};
  @override
  dynamic get(dynamic key, {required dynamic defaultValue}) =>
      values.containsKey(key) ? values[key] : defaultValue;
  @override
  Future<void> put(dynamic key, dynamic value) async => values[key] = value;
  @override
  Future<void> onDispose() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
