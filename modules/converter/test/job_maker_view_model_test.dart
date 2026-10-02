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
  var modelDisposed = false;

  setUp(() {
    modelDisposed = false;
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
    if (!modelDisposed) model.dispose();
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

  test(
    'provider destinations keep FFmpeg output in the app temporary directory',
    () async {
      await model.addFiles([File('/input/song.wav')]);
      await model.setSelectedFormatEntry(mp3);
      model.setOutputDirectoryPath(OutputDestination.downloads);
      final cooked = (await model.cook()).single;
      expect(cooked.outputDirectoryPath, OutputDestination.downloads);
      expect(cooked.convertedFilePath, startsWith('/temporary/'));
      expect(
        CommandBuilder.parseCommand(cooked.command).last,
        cooked.convertedFilePath,
      );
      expect(cooked.outputUri, isNull);
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
    'partial preparation rolls inputs back so the batch can retry',
    () async {
      final first = File('/service-cache/file_picker/first.wav');
      final second = File('/service-cache/file_picker/second.wav');
      await model.addFiles([first, second]);
      await model.setSelectedFormatEntry(mp3);
      model.setOutputDirectoryPath('/output');
      model.setOutputFileName(first.path, 'custom.mp3');
      files.failedPreparationPath = second.path;
      await expectLater(model.cook(), throwsA(isA<InputFileNotExistFailure>()));
      expect(await files.isFileExist(first.path), isTrue);
      expect(model.selectedFiles.map((file) => file.path), [
        first.path,
        second.path,
      ]);
      expect(files.restoredInputs, [first.path]);
      files.failedPreparationPath = null;
      final jobs = await model.cook();
      expect(jobs, hasLength(2));
      expect(jobs.first.outputFileName, 'custom.mp3');
      expect(jobs.last.outputFileName, 'second.mp3');
    },
  );

  test(
    'failed rollback retains its staged source and ownership across retries',
    () async {
      final first = File('/service-cache/file_picker/first.wav');
      final second = File('/service-cache/file_picker/second.wav');
      await model.addFiles([first, second]);
      await model.setSelectedFormatEntry(mp3);
      model.setOutputDirectoryPath('/output');
      model.setOutputFileName(first.path, 'custom.mp3');
      model.setFileTrim(
        first.path,
        const FileTrimResult(
          duration: Duration(seconds: 5),
          trim: ConversionTrim(
            start: Duration(seconds: 1),
            end: Duration(seconds: 2),
          ),
        ),
      );
      files.failedPreparationPath = second.path;
      files.failRestoration = true;
      await expectLater(model.cook(), throwsA(isA<InputFileNotExistFailure>()));
      final staged = model.selectedFiles.first;
      final owner = files.stagedOwners[staged.path]!;
      expect(staged.path, isNot(first.path));
      expect(model.outputFileNames[staged.path], 'custom.mp3');
      expect(model.fileContentType(staged), FileContentType.audio);
      expect(model.trimFor(first.path), isNull);
      expect(model.trimFor(staged.path)!.arguments, [
        '-ss',
        '1.000',
        '-t',
        '1.000',
      ]);
      await expectLater(model.cook(), throwsA(isA<InputFileNotExistFailure>()));
      expect(await files.isFileExist(staged.path), isTrue);
      expect(files.cleanedInputs, isNot(contains(owner)));
      files.failedPreparationPath = null;
      final jobs = await model.cook();
      expect(jobs.first.id, owner);
      expect(jobs.first.inputFilePath, staged.path);
      expect(jobs.first.outputFileName, 'custom.mp3');
      expect(
        CommandBuilder.parseCommand(jobs.first.command),
        containsAllInOrder(['-ss', '1.000', '-t', '1.000']),
      );
    },
  );

  test(
    'discarding setup cleans only its retained, unsubmitted input',
    () async {
      final first = File('/service-cache/file_picker/first.wav');
      final second = File('/service-cache/file_picker/second.wav');
      await model.addFiles([first, second]);
      await model.setSelectedFormatEntry(mp3);
      model.setOutputDirectoryPath('/output');
      files.failedPreparationPath = second.path;
      files.failRestoration = true;
      await expectLater(model.cook(), throwsA(isA<InputFileNotExistFailure>()));
      final owner = files.stagedOwners[model.selectedFiles.first.path]!;
      model.dispose();
      modelDisposed = true;
      await Future<void>.delayed(Duration.zero);
      expect(files.cleanedInputs, contains(owner));
      expect(files.stagedOwners, isEmpty);
      expect(await files.isFileExist(second.path), isTrue);
    },
  );

  test('closing setup during preparation restores moved inputs', () async {
    final first = File('/service-cache/file_picker/first.wav');
    await model.addFiles([
      first,
      File('/service-cache/file_picker/second.wav'),
    ]);
    await model.setSelectedFormatEntry(mp3);
    model.setOutputDirectoryPath('/output');
    files.preparationGate = Completer<void>();
    final result = model.cook();
    final assertion = expectLater(result, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    model.dispose();
    modelDisposed = true;
    files.preparationGate!.complete();
    await assertion;
    expect(files.preparedInputs, [first.path]);
    expect(files.restoredInputs, [first.path]);
    expect(await files.isFileExist(first.path), isTrue);
  });

  test('failed submission restores the batch and retains names and per-file trim for retry', () async {
    final source = File('/service-cache/file_picker/song.wav');
    await model.addFiles([source]);
    await model.setSelectedFormatEntry(mp3);
    model.setOutputDirectoryPath('/output');
    model.setOutputFileName(source.path, 'chosen.mp3');
    const trim = ConversionTrim(
      start: Duration(seconds: 1),
      end: Duration(seconds: 2),
    );
    model.setFileTrim(
      source.path,
      const FileTrimResult(duration: Duration(seconds: 4), trim: trim),
    );
    await expectLater(
      model.cook(
        onSubmitJobs: (_) async {
          throw const FailedToQueueJobsFailure();
        },
      ),
      throwsA(isA<FailedToQueueJobsFailure>()),
    );
    expect(model.isPreparingJobs, isFalse);
    expect(await files.isFileExist(source.path), isTrue);
    expect(model.selectedFiles.single.path, source.path);
    expect(model.outputFileNames[source.path], 'chosen.mp3');
    expect(model.trimFor(source.path), trim);
    List<ConvertJob>? submitted;
    final jobs = await model.cook(
      onSubmitJobs: (jobs) async => submitted = jobs,
    );
    expect(submitted, same(jobs));
    expect(jobs.single.outputFileName, 'chosen.mp3');
    expect(
      CommandBuilder.parseCommand(jobs.single.command),
      containsAllInOrder(['-ss', '1.000', '-t', '1.000']),
    );
  });

  test('submission holds preparation and overlapping starts share one accepted batch', () async {
    await model.addFiles([File('/input/song.wav')]);
    await model.setSelectedFormatEntry(mp3);
    model.setOutputDirectoryPath('/output');
    final gate = Completer<void>();
    var calls = 0;
    final first = model.cook(
      onSubmitJobs: (_) async {
        calls++;
        await gate.future;
      },
    );
    final second = model.cook(onSubmitJobs: (_) async => calls++);
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    expect(model.isPreparingJobs, isTrue);
    expect(second, same(first));
    gate.complete();
    expect(await second, same(await first));
    expect(model.isPreparingJobs, isFalse);
    expect(calls, 1);
  });

  test('closing during a successful submission preserves retained inputs accepted by the queue', () async {
    final source = File('/service-cache/file_picker/song.wav');
    await model.addFiles([source]);
    await model.setSelectedFormatEntry(mp3);
    model.setOutputDirectoryPath('/output');
    files.failRestoration = true;
    await expectLater(
      model.cook(
        onSubmitJobs: (_) async {
          throw const FailedToQueueJobsFailure();
        },
      ),
      throwsA(isA<FailedToQueueJobsFailure>()),
    );
    final retained = model.selectedFiles.single.path;
    final owner = files.stagedOwners[retained]!;
    final gate = Completer<void>();
    List<ConvertJob>? submitted;
    final cooking = model.cook(
      onSubmitJobs: (jobs) async {
        submitted = jobs;
        await gate.future;
      },
    );
    await Future<void>.delayed(Duration.zero);
    expect(submitted, isNotNull);
    model.dispose();
    modelDisposed = true;
    expect(files.cleanedInputs, isNot(contains(owner)));
    gate.complete();
    final jobs = await cooking;
    expect(jobs.single.id, owner);
    expect(await files.isFileExist(retained), isTrue);
    expect(files.cleanedInputs, isNot(contains(owner)));
  });

  test(
    'closing during a failed submission cleans only unsubmitted retained input',
    () async {
      final source = File('/service-cache/file_picker/song.wav');
      await model.addFiles([source]);
      await model.setSelectedFormatEntry(mp3);
      model.setOutputDirectoryPath('/output');
      files.failRestoration = true;
      await expectLater(
        model.cook(
          onSubmitJobs: (_) async {
            throw const FailedToQueueJobsFailure();
          },
        ),
        throwsA(isA<FailedToQueueJobsFailure>()),
      );
      final owner = files.stagedOwners[model.selectedFiles.single.path]!;
      final gate = Completer<void>();
      final cooking = model.cook(
        onSubmitJobs: (_) async {
          await gate.future;
          throw const FailedToQueueJobsFailure();
        },
      );
      final assertion = expectLater(
        cooking,
        throwsA(isA<FailedToQueueJobsFailure>()),
      );
      await Future<void>.delayed(Duration.zero);
      model.dispose();
      modelDisposed = true;
      gate.complete();
      await assertion;
      expect(files.cleanedInputs, contains(owner));
      expect(files.stagedOwners, isEmpty);
    },
  );

  test(
    'asynchronous preference failure cannot roll back an accepted batch',
    () async {
      final source = File('/service-cache/file_picker/song.wav');
      await model.addFiles([source]);
      await model.setSelectedFormatEntry(mp3);
      model.setOutputDirectoryPath('/output');
      model.setRememberConfigs(true);
      final configs =
          injector<JobConfigurationData>() as FakeJobConfigurationData;
      configs.failWrites = true;
      var accepted = false;
      final jobs = await model.cook(onSubmitJobs: (_) async => accepted = true);
      expect(accepted, isTrue);
      expect(await files.isFileExist(jobs.single.inputFilePath), isTrue);
      expect(files.restoredInputs, isEmpty);
      expect(files.cleanedInputs, isEmpty);
    },
  );

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
    'file trims validate independently and generate separate job ranges',
    () async {
      const duration = Duration(seconds: 10);
      await model.addFiles([
        File('/input/song.wav'),
        File('/input/short.wav'),
        File('/input/full.wav'),
      ]);
      await model.setSelectedFormatEntry(mp3);
      model.setOutputDirectoryPath('/output');
      expect(
        () => model.setFileTrim(
          '/input/song.wav',
          const FileTrimResult(
            duration: duration,
            trim: ConversionTrim(
              start: Duration(seconds: 2),
              end: Duration(seconds: 1),
            ),
          ),
        ),
        throwsA(isA<InvalidTrimRangeFailure>()),
      );
      expect(
        () => model.setFileTrim(
          '/input/short.wav',
          const FileTrimResult(
            duration: Duration(seconds: 2),
            trim: ConversionTrim(end: Duration(seconds: 3)),
          ),
        ),
        throwsA(isA<InvalidTrimBoundsFailure>()),
      );
      model.setFileTrim(
        '/input/song.wav',
        const FileTrimResult(
          duration: duration,
          trim: ConversionTrim(
            start: Duration(milliseconds: 2125),
            end: Duration(milliseconds: 3500),
          ),
        ),
      );
      model.setFileTrim(
        '/input/short.wav',
        const FileTrimResult(
          duration: Duration(seconds: 2),
          trim: ConversionTrim(start: Duration(milliseconds: 500)),
        ),
      );
      model.resetConfigurations();
      await model.setSelectedFormatEntry(mp4);
      final jobs = await model.cook();
      final args = jobs
          .map((job) => CommandBuilder.parseCommand(job.command))
          .toList();
      expect(args[0], containsAllInOrder(['-ss', '2.125', '-t', '1.375']));
      expect(args[1], containsAllInOrder(['-ss', '0.500']));
      expect(args[1], isNot(contains('-t')));
      expect(args[2], isNot(contains('-ss')));
      expect(args[2], isNot(contains('-t')));
      model.setFileTrim(
        '/input/song.wav',
        const FileTrimResult(duration: duration),
      );
      expect(model.trimFor('/input/song.wav'), isNull);
      expect(model.trimFor('/input/short.wav'), isNotNull);
      model.removeFile(File('/input/short.wav'));
      await model.addFiles([File('/input/short.wav')]);
      expect(model.trimFor('/input/short.wav'), isNull);
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
  bool failWrites = false;
  @override
  Future<void> put(dynamic key, dynamic value) async {
    if (failWrites) throw StateError('Cannot save preferences');
  }

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
  String? failedPreparationPath;
  var failRestoration = false;
  final missingInputs = <String>{};
  final stagedOwners = <String, String>{};
  final restoredInputs = <String>[];
  final cleanedInputs = <String>[];

  @override
  Future<bool> outputExists(String destination, String name) =>
      isFileExist(join(destination, name));

  @override
  Future<Directory> getAppCacheDirectory() async => Directory('/service-cache');

  @override
  Future<bool> isMediaFile(File file) async => true;

  @override
  Future<String?> getFileMimeType(File file) async =>
      delayedMimeTypes[file.path] ?? 'audio/wav';

  @override
  Future<bool> isFileExist(String path) async {
    if (missingInputs.contains(path)) return false;
    return delayedOutputs[path] ??
        (path.startsWith('/input/') ||
            path.startsWith('/service-cache/file_picker/') ||
            stagedOwners.containsKey(path) ||
            existingOutputs.contains(path));
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
    if (inputFilePath == failedPreparationPath) return null;
    if (inputFilePath.startsWith('/service-cache/file_picker/')) {
      final staged = '/prepared/$jobId/${basename(inputFilePath)}';
      missingInputs.add(inputFilePath);
      stagedOwners[staged] = jobId;
      return staged;
    }
    return inputFilePath;
  }

  @override
  Future<String?> restorePickedFile({
    required String jobId,
    required String originalFilePath,
    required String preparedFilePath,
  }) async {
    restoredInputs.add(originalFilePath);
    if (failRestoration) return preparedFilePath;
    missingInputs.remove(originalFilePath);
    stagedOwners.remove(preparedFilePath);
    return originalFilePath;
  }

  @override
  Future<void> cleanUpInputFile({required String jobId}) async {
    cleanedInputs.add(jobId);
    stagedOwners.removeWhere((path, owner) => owner == jobId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
