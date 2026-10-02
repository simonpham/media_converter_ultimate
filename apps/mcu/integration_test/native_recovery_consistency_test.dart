import 'dart:async';

import 'package:converter/converter.dart';
import 'package:core_storage_base/core_storage_base.dart';
import 'package:core_storage_isar/core_storage_isar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:platform_utils/platform_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final prefix = 'MCU_Recovery_QA_${DateTime.now().microsecondsSinceEpoch}';
  late Directory directory;
  late Isar isar;
  late ConvertJobIsarStorage storage;
  late _Files files;
  late _Settings settings;
  late _Runner runner;
  late JobManagerViewModel manager;
  final inputIds = <String>{};

  setUp(() async {
    files = _Files();
    settings = _Settings();
    runner = _Runner();
    injector.registerSingleton<FileService>(files);
    injector.registerSingleton<SettingsBox>(settings);
    injector.registerSingleton<LogData>(_Logs());
    injector.registerSingleton<JobRunnerService>(runner);
    directory = await (await files.getAppCacheDirectory()).createTemp(prefix);
    isar = await Isar.open(
      [IsarConvertJobSchema],
      directory: directory.path,
      name: 'recovery-consistency-qa',
    );
    storage = ConvertJobIsarStorage(isar: isar);
    injector.registerSingleton<ConvertJobStorage>(storage);
    manager = JobManagerViewModel();
  });

  tearDown(() async {
    manager.dispose();
    for (final location in files.outputs) {
      if (await files.isFileExist(location)) await files.deleteOutput(location);
      expect(await files.isFileExist(location), isFalse);
    }
    for (final id in files.exportIds) {
      await files.acknowledgeExport(id);
    }
    for (final id in inputIds) {
      await files.cleanUpInputFile(jobId: id);
    }
    inputIds.clear();
    await isar.close(deleteFromDisk: true);
    await injector.reset();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  ConvertJob record(String suffix, {JobStatus status = .actionRequired}) {
    final now = DateTime.now();
    return .new(
      id: '$prefix-$suffix',
      inputFilePath: '${directory.path}/input-$suffix.mp3',
      outputFileName: '$prefix $suffix.mp3',
      outputExtension: 'mp3',
      outputDirectoryPath: '${directory.path}/blocked',
      command: '[]',
      convertedFilePath: '${directory.path}/stage-$suffix.mp3',
      status: status,
      outputStaged: status == .actionRequired,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<ConvertJob> stage(String suffix) async {
    final job = record(suffix);
    final generated = await FFmpegKit.executeWithArguments([
      '-f',
      'lavfi',
      '-i',
      'anullsrc=r=48000:cl=mono',
      '-t',
      '0.25',
      '-c:a',
      'libmp3lame',
      job.convertedFilePath,
    ]);
    expect(
      ReturnCode.isSuccess(await generated.getReturnCode()),
      isTrue,
      reason: await generated.getAllLogsAsString(),
    );
    final input = await files.getInputDirectory(job.id);
    inputIds.add(job.id);
    final source = await File(job.convertedFilePath)
        .copy('${input.path}/source.mp3');
    final staged = job.copyWith(inputFilePath: .new(source.path));
    expect(await storage.add(staged), isNull);
    return staged;
  }

  testWidgets(
    'overlapping rename and folder recovery preserve saved MP3 bytes',
    (_) async {
      final job = await stage('collision');
      final bytes = await File(job.convertedFilePath).readAsBytes();
      final renamed = '$prefix Việt renamed.mp3';
      final blocked = await Directory(job.outputDirectoryPath)
          .create(recursive: true);
      final collision = await File('${blocked.path}/$renamed')
          .writeAsString('owned collision');
      final chosen = '${directory.path}/chosen';
      files.exportEntered = Completer<void>();
      final release = files.exportRelease = Completer<void>();
      final renaming = manager.handleJobRenameAction(job, renamed);
      await files.exportEntered!.future.timeout(const Duration(seconds: 10));
      final changing = manager.handleJobChooseAnotherPathAction(job, chosen);
      release.complete();
      final results = await Future.wait([renaming, changing]);
      expect(results.first, isA<OutputFileAlreadyExistsFailure>());
      expect(results.last, isNull);
      final completed = (await storage.get(job.id))!;
      expect(completed.status, JobStatus.completed);
      expect(completed.outputFileName, renamed);
      expect(completed.outputDirectoryPath, chosen);
      expect(await File(completed.outputLocation).readAsBytes(), bytes);
      expect(await collision.readAsString(), 'owned collision');
      expect(await File(job.convertedFilePath).exists(), isFalse);
      expect(await File(job.inputFilePath).exists(), isFalse);
      expect(files.exportNames, [renamed, renamed]);
      expect(files.copies, 0);
      expect(runner.starts, 0);
      expect(settings.successConversionCount, 1);
      expect(await manager.retryExport(job), isA<InvalidStatusFailure>());
      expect(files.exportNames, hasLength(2));
      printLog(
        '[Native recovery QA] overlapping choices retained name, folder and exact bytes',
      );
    },
  );

  testWidgets(
    'MediaStore receipt recovery and removal leave no recreated history',
    (_) async {
      final job = await stage('receipt');
      final bytes = await File(job.convertedFilePath).readAsBytes();
      final name = '$prefix Việt published.mp3';
      final (published, failure) = await files.exportFile(
        exportId: job.id,
        source: job.convertedFilePath,
        destination: OutputDestination.downloads,
        name: name,
      );
      expect(failure, isNull);
      expect(published, isNotNull);
      expect(published!.location, startsWith('content://'));
      files.recoverEntered = Completer<void>();
      final release = files.recoverRelease = Completer<void>();
      final startup = manager.initialize();
      await files.recoverEntered!.future.timeout(const Duration(seconds: 10));
      final removal = manager.removeJob(job);
      final duplicate = manager.retryExport(job);
      final retainedDuringRecovery = await File(job.convertedFilePath).exists();
      release.complete();
      await startup;
      expect(await removal, isNull);
      expect(await duplicate, isA<InvalidStatusFailure>());
      expect(retainedDuringRecovery, isTrue);
      expect(await storage.get(job.id), isNull);
      expect(await storage.count(), 0);
      expect(await files.isFileExist(published.location), isTrue);
      expect(await files.recoverExport(job.id), isNull);
      final readable = await FFmpegKitConfig.getSafParameterForRead(
        published.location,
      );
      expect(readable, isNotNull);
      final copied = '${directory.path}/published-roundtrip.mp3';
      final copiedSession = await FFmpegKit.executeWithArguments([
        '-f',
        'data',
        '-i',
        readable!,
        '-map',
        '0',
        '-c',
        'copy',
        '-f',
        'data',
        copied,
      ]);
      expect(
        ReturnCode.isSuccess(await copiedSession.getReturnCode()),
        isTrue,
        reason: await copiedSession.getAllLogsAsString(),
      );
      expect(await File(copied).readAsBytes(), bytes);
      expect(await File(job.convertedFilePath).exists(), isFalse);
      expect(await File(job.inputFilePath).exists(), isFalse);
      expect(files.exportNames, [name]);
      expect(files.copies, 0);
      expect(runner.starts, 0);
      expect(settings.successConversionCount, 1);
      printLog(
        '[Native recovery QA] real receipt committed once; history removed; public bytes preserved',
      );
    },
  );

  testWidgets('Android repair preserves commits made before its transaction', (
    _,
  ) async {
    Future<List<ConvertJob>> repairAfter(
      ConvertJob job,
      Future<void> Function() change,
    ) async {
      expect(await storage.add(job), isNull);
      final held = _HeldIsar(isar);
      final repairing = ConvertJobIsarStorage(isar: held).fixInvalidJobs();
      await held.entered.future.timeout(const Duration(seconds: 10));
      try {
        await change();
      } finally {
        held.release.complete();
      }
      return repairing;
    }

    final removed = record('removed', status: .pending);
    expect(
      await repairAfter(removed, () async {
        expect(await storage.delete(removed.id), isNull);
      }),
      isEmpty,
    );
    expect(await storage.get(removed.id), isNull);
    final completed = record('completed', status: .running);
    expect(
      await repairAfter(completed, () async {
        expect(
          await storage.update(
            completed.copyWith(
              status: const .new(.completed),
              outputFileName: const .new('preserved.mp3'),
              outputUri: const .new(
                'content://media/downloads/metadata-fixture',
              ),
            ),
          ),
          isNull,
        );
      }),
      isEmpty,
    );
    final kept = (await storage.get(completed.id))!;
    expect(kept.status, JobStatus.completed);
    expect(kept.outputFileName, 'preserved.mp3');
    expect(kept.outputUri, 'content://media/downloads/metadata-fixture');
    final changed = record('changed', status: .preparing);
    final fixed = await repairAfter(changed, () async {
      expect(
        await storage.update(
          changed.copyWith(
            status: const .new(.running),
            outputFileName: const .new('new-name.mp3'),
            command: const .new('updated trim command'),
            sessionId: const .new(42),
          ),
        ),
        isNull,
      );
    });
    expect(fixed.single.outputFileName, 'new-name.mp3');
    expect(fixed.single.command, 'updated trim command');
    expect(fixed.single.status, JobStatus.pending);
    expect(fixed.single.sessionId, isNull);
    expect((await storage.get(changed.id))!.toJson(), fixed.single.toJson());
    expect(runner.starts, 0);
    printLog(
      '[Native recovery QA] Android transaction protects deletion, completion and new settings',
    );
  });
}

class _Files extends DirectFileService {
  Completer<void>? exportEntered;
  Completer<void>? exportRelease;
  Completer<void>? recoverEntered;
  Completer<void>? recoverRelease;
  final outputs = <String>{};
  final exportIds = <String>{};
  final exportNames = <String>[];
  int copies = 0;
  @override
  Future<(ExportedFile?, Failure?)> exportFile({
    required String exportId,
    required String source,
    required String destination,
    required String name,
  }) async {
    exportIds.add(exportId);
    exportNames.add(name);
    final release = exportRelease;
    exportRelease = null;
    if (release != null) {
      exportEntered!.complete();
      await release.future;
    }
    final result = await super.exportFile(
      exportId: exportId,
      source: source,
      destination: destination,
      name: name,
    );
    if (result.$1 case final output?) outputs.add(output.location);
    return result;
  }

  @override
  Future<ExportedFile?> recoverExport(String exportId) async {
    final release = recoverRelease;
    recoverRelease = null;
    if (release != null) {
      recoverEntered!.complete();
      await release.future;
    }
    return super.recoverExport(exportId);
  }

  @override
  Future<(String?, Failure?)> copyTempOutputFileToConverted({
    required String jobId,
    required String convertedFilePath,
  }) {
    copies++;
    return super.copyTempOutputFileToConverted(
      jobId: jobId,
      convertedFilePath: convertedFilePath,
    );
  }
}

class _HeldIsar(final Isar delegate) implements Isar {
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  IsarCollection<T> collection<T>() => delegate.collection<T>();
  @override
  Future<T> writeTxn<T>(
    Future<T> Function() action, {
    bool silent = false,
  }) async {
    entered.complete();
    await release.future;
    return delegate.writeTxn(action, silent: silent);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Runner implements JobRunnerService {
  int starts = 0;
  @override
  Future<ConvertJob> run(ConvertJob job) async {
    starts++;
    throw StateError('Recovery must reuse the saved output');
  }

  @override
  Stream<ConvertJob> get onJobUpdate => const Stream.empty();
  @override
  Stream<JobLog> get onLogUpdate => const Stream.empty();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Settings implements SettingsBox {
  final values = <dynamic, dynamic>{};
  @override
  dynamic get(dynamic key, {required dynamic defaultValue}) =>
      values[key] ?? defaultValue;
  @override
  Future<void> put(dynamic key, dynamic value) async => values[key] = value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Logs implements LogData {
  final values = <dynamic, dynamic>{};
  @override
  dynamic get(dynamic key, {required dynamic defaultValue}) =>
      values[key] ?? defaultValue;
  @override
  Future<void> put(dynamic key, dynamic value) async => values[key] = value;
  @override
  Future<void> clearLogs(Iterable<String> ids) async {
    for (final id in ids) {
      values.remove(id);
    }
  }

  @override
  Future<void> onDispose() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
