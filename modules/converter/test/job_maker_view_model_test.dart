import 'dart:async';
import 'dart:convert';

import 'package:converter/converter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_utils/platform_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mp3 = FormatEntry(
    name: 'mp3',
    outputExtension: 'mp3',
    outputType: .audio,
    shouldAddToArgs: true,
  );
  const mp4 = FormatEntry(
    name: 'mp4',
    outputExtension: 'mp4',
    outputType: .video,
    shouldAddToArgs: true,
  );

  late FakeFileService files;
  late JobMakerViewModel model;

  setUp(() {
    files = FakeFileService();
    injector.registerSingleton<SettingsBox>(FakeSettingsBox());
    injector.registerSingleton<JobConfigurationData>(
      FakeJobConfigurationData(),
    );
    injector.registerSingleton<FileService>(files);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler('flutter/assets', (_) async {
      return ByteData.sublistView(Uint8List.fromList(utf8.encode('{}')));
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => '/cache',
    );
    model = JobMakerViewModel(
      formatConfigModel: const FormatConfigModel(
        formats: [mp3, mp4],
        uiGradients: {},
      ),
      translations: const {},
    );
  });

  tearDown(() async {
    model.dispose();
    await injector.reset();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler('flutter/assets', null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
  });

  test(
    'deduplicates repeated files within a picker result and across picks',
    () async {
      final song = File('/input/song.wav');
      await model.addFiles([song, song, File(song.path)]);
      await model.addFiles([song]);
      expect(model.selectedFiles.map((file) => file.path), [song.path]);
    },
  );

  test(
    'overlapping picks merge without restoring a file removed during detection',
    () async {
      final removed = File('/input/removed.wav');
      await model.addFiles([removed]);
      final gate = Completer<String?>();
      files.delayedMimeTypes['/input/slow.mp4'] = gate.future;
      final slow = model.addFiles([File('/input/slow.mp4')]);
      await model.addFiles([File('/input/fast.wav')]);
      model.removeFile(removed);
      gate.complete('video/mp4');
      await slow;
      expect(model.selectedFiles.map((file) => file.path), [
        '/input/fast.wav',
        '/input/slow.mp4',
      ]);
      expect(
        model.fileContentType(File('/input/slow.mp4')),
        FileContentType.video,
      );
      expect(model.fileContentType(removed), FileContentType.other);
    },
  );

  test('missing MIME information safely excludes an unreadable file', () async {
    final file = File('/input/deleted.wav');
    files.delayedMimeTypes[file.path] = Future.value(null);
    await model.addFiles([file]);
    expect(model.selectedFiles, isEmpty);
    expect(model.excludedFiles.map((file) => file.path), [file.path]);
    expect(model.fileContentType(file), FileContentType.other);
  });

  test(
    'selecting a format populates output names without mutating a const map',
    () async {
      await model.addFiles([File('/input/song.wav')]);
      await model.setSelectedFormatEntry(mp3);
      expect(model.outputFileNames, {'/input/song.wav': 'song.mp3'});
    },
  );

  test('removed files leave neither output names nor jobs', () async {
    final removed = File('/input/removed.wav');
    await model.addFiles([removed, File('/input/kept.wav')]);
    await model.setSelectedFormatEntry(mp3);
    model.setOutputDirectoryPath('/output');
    model.removeFile(removed);
    expect(model.outputFileNames, {'/input/kept.wav': 'kept.mp3'});
    final jobs = await model.cook();
    expect(jobs.map((job) => job.inputFilePath), ['/input/kept.wav']);
    model.setOutputFileName(removed.path, 'ghost.mp3');
    expect(model.outputFileNames.containsKey(removed.path), isFalse);
  });

  test('jobs follow the order chosen in the batch preview', () async {
    await model.addFiles([File('/input/first.wav'), File('/input/second.wav')]);
    await model.setSelectedFormatEntry(mp3);
    model.setOutputDirectoryPath('/output');
    model.reorderFile(0, 1);
    final jobs = await model.cook();
    expect(jobs.map((job) => job.inputFilePath), [
      '/input/second.wav',
      '/input/first.wav',
    ]);
  });

  test(
    'changing format replaces extensions and excludes removed files',
    () async {
      final removed = File('/input/removed.wav');
      await model.addFiles([removed, File('/input/kept.wav')]);
      await model.setSelectedFormatEntry(mp3);
      model.setOutputFileName('/input/kept.wav', 'custom.mp3');
      model.removeFile(removed);
      await model.setSelectedFormatEntry(mp4);
      expect(model.outputFileNames, {'/input/kept.wav': 'kept.mp4'});
    },
  );

  test('overlapping preparation shares one batch and resolves cache through the service', () async {
    await model.addFiles([File('/input/first.wav'), File('/input/second.wav')]);
    await model.setSelectedFormatEntry(mp3);
    model.setOutputDirectoryPath('/output');
    files.preparationGate = Completer<void>();
    final first = model.cook();
    final second = model.cook();
    expect(identical(first, second), isTrue);
    expect(model.isPreparingJobs, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(files.preparedInputs, ['/input/first.wav']);
    files.preparationGate!.complete();
    final jobs = await first;
    expect(await second, same(jobs));
    expect(jobs, hasLength(2));
    expect(files.preparedInputs, ['/input/first.wav', '/input/second.wav']);
    expect(files.cachePaths, ['/service-cache', '/service-cache']);
    expect(model.isPreparingJobs, isFalse);
  });

  test(
    'a validation failure releases preparation for a corrected retry',
    () async {
      await model.addFiles([File('/input/song.wav')]);
      await model.setSelectedFormatEntry(mp3);
      await expectLater(model.cook(), throwsA(isA<NoOutputFolderFailure>()));
      expect(model.isPreparingJobs, isFalse);
      model.setOutputDirectoryPath('/output');
      expect(await model.cook(), hasLength(1));
      expect(model.isPreparingJobs, isFalse);
    },
  );

  test(
    'jobs use the same format, names, and directory throughout preparation',
    () async {
      await model.addFiles([
        File('/input/first.wav'),
        File('/input/second.wav'),
      ]);
      await model.setSelectedFormatEntry(mp3);
      model.setOutputDirectoryPath('/original-output');
      files.preparationGate = Completer<void>();
      final preparation = model.cook();
      await Future<void>.delayed(Duration.zero);
      await model.setSelectedFormatEntry(mp4);
      model.setOutputDirectoryPath('/new-output');
      model.setOutputFileName('/input/second.wav', 'changed.mp4');
      files.preparationGate!.complete();
      final jobs = await preparation;
      expect(jobs.map((job) => job.outputFileName), [
        'first.mp3',
        'second.mp3',
      ]);
      expect(jobs.map((job) => job.outputExtension), everyElement('mp3'));
      expect(
        jobs.map((job) => job.outputDirectoryPath),
        everyElement('/original-output'),
      );
      for (final job in jobs) {
        expect(
          CommandBuilder.parseCommand(job.command),
          containsAllInOrder(['-f', 'mp3']),
        );
      }
    },
  );

  test(
    'trimming validates ranges and snapshots precise command options',
    () async {
      await model.addFiles([File('/input/song.wav')]);
      await model.setSelectedFormatEntry(mp3);
      model.setOutputDirectoryPath('/output');
      model.setTrimEnabled(true);
      model.setTrimStartText('0:02.125');
      model.setTrimEndText('0:01');
      expect(model.trimRangeFailure, isA<InvalidTrimRangeFailure>());
      await expectLater(model.cook(), throwsA(isA<InvalidTrimRangeFailure>()));
      model.setTrimEndText('0:03.5');
      final jobs = await model.cook();
      expect(
        CommandBuilder.parseCommand(jobs.single.command),
        containsAllInOrder(['-ss', '2.125', '-t', '1.375']),
      );
      model.setTrimEndText('invalid');
      expect(model.trimEndFailure, isA<InvalidTrimTimestampFailure>());
      model.setTrimEnabled(false);
      final fullTrack = await model.cook();
      expect(
        CommandBuilder.parseCommand(fullTrack.single.command),
        isNot(contains('-ss')),
      );
      expect(
        CommandBuilder.parseCommand(fullTrack.single.command),
        isNot(contains('-t')),
      );
    },
  );

  test('rejects an empty batch before preparing jobs', () async {
    await model.setSelectedFormatEntry(mp3);
    model.setOutputDirectoryPath('/output');
    await expectLater(model.cook(), throwsA(isA<NoFilesSelectedFailure>()));
  });

  test('path validation uses its supplied directory snapshot', () async {
    await model.addFiles([File('/input/song.wav')]);
    await model.setSelectedFormatEntry(mp3);
    model.setOutputDirectoryPath('/new-output');
    files.existingOutputs.add('/snapshot-output/song.mp3');
    final failures = await model.findInvalidPaths(
      selectedPaths: model.outputFileNames,
      outputDirectoryPath: '/snapshot-output',
    );
    expect(failures['/input/song.wav'], isA<OutputFileAlreadyExistsFailure>());
  });

  test('older validation cannot overwrite a newer rename result', () async {
    await model.addFiles([File('/input/song.wav')]);
    await model.setSelectedFormatEntry(mp3);
    final delayedResult = Completer<bool>();
    files.delayedOutputs['/output/song.mp3'] = delayedResult.future;
    model.setOutputDirectoryPath('/output');
    await Future<void>.delayed(Duration.zero);
    model.setOutputFileName('/input/song.wav', 'renamed.mp3');
    await Future<void>.delayed(Duration.zero);
    expect(model.errorPaths, isEmpty);
    delayedResult.complete(true);
    await Future<void>.delayed(Duration.zero);
    expect(model.errorPaths, isEmpty);
  });

  test('missing output names produce a typed validation failure', () async {
    await model.setSelectedFormatEntry(mp3);
    final failures = await model.findInvalidPaths(
      selectedPaths: {'/input/song.wav': null},
      outputDirectoryPath: '/output',
    );
    expect(failures['/input/song.wav'], isA<FileNameIsNotSetFailure>());
  });
}

class FakeSettingsBox implements SettingsBox {
  @override
  dynamic get(dynamic key, {required dynamic defaultValue}) => defaultValue;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeJobConfigurationData implements JobConfigurationData {
  @override
  Future<void> onDispose() async {}

  @override
  dynamic get(dynamic key, {required dynamic defaultValue}) => defaultValue;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFileService implements FileService {
  final existingOutputs = <String>{};
  final delayedOutputs = <String, Future<bool>>{};
  final delayedMimeTypes = <String, Future<String?>>{};
  final preparedInputs = <String>[];
  final cachePaths = <String>[];
  Completer<void>? preparationGate;

  @override
  Future<Directory> getAppCacheDirectory() async => Directory('/service-cache');

  @override
  Future<bool> isMediaFile(File file) async => true;

  @override
  Future<String?> getFileMimeType(File file) async =>
      delayedMimeTypes[file.path] ?? 'audio/wav';

  @override
  Future<bool> isFileExist(String path) async {
    return delayedOutputs[path] ??
        (path.startsWith('/input/') || existingOutputs.contains(path));
  }

  @override
  Future<Directory> getConvertTemporaryDirectory(String? prefix) async =>
      Directory('/temporary');

  @override
  Future<String?> movePickedFileToInputFolder({
    required String jobId,
    required String inputFilePath,
    required String appCachedPath,
  }) async {
    preparedInputs.add(inputFilePath);
    cachePaths.add(appCachedPath);
    await preparationGate?.future;
    return inputFilePath;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
