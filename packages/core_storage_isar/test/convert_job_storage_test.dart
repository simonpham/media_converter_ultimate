import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:core/core.dart';
import 'package:core_storage_isar/core_storage_isar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utils/utils.dart';

void main() {
  late Directory temporaryDirectory;
  late Isar isar;
  late ConvertJobIsarStorage storage;

  setUpAll(() async {
    var directory = Directory.current;
    var packageConfig = File(
      '${directory.path}/.dart_tool/package_config.json',
    );
    while (!await packageConfig.exists()) {
      if (directory.parent.path == directory.path) {
        throw StateError('Unable to find the workspace package configuration');
      }
      directory = directory.parent;
      packageConfig = File('${directory.path}/.dart_tool/package_config.json');
    }
    final configuration = jsonDecode(await packageConfig.readAsString()) as Map;
    final nativePackage = (configuration['packages'] as List)
        .cast<Map>()
        .singleWhere(
          (package) => package['name'] == 'isar_community_flutter_libs',
        );
    final packageUri = Directory.fromUri(
      packageConfig.uri.resolve(
        nativePackage['rootUri'] as String,
      ),
    ).uri;
    final nativePath = switch (Platform.operatingSystem) {
      'macos' => 'macos/libisar.dylib',
      'linux' => 'linux/libisar.so',
      'windows' => 'windows/libisar.dll',
      _ => throw UnsupportedError('Isar integration tests need a desktop host'),
    };
    await Isar.initializeIsarCore(
      libraries: {
        Abi.current(): File.fromUri(packageUri.resolve(nativePath)).path,
      },
    );
  });

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'mcu-storage-test-',
    );
    isar = await Isar.open(
      [IsarConvertJobSchema],
      directory: temporaryDirectory.path,
      name: 'queue-test',
    );
    storage = ConvertJobIsarStorage(isar: isar);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    await temporaryDirectory.delete(recursive: true);
  });

  test(
    'pending query and stream preserve creation order after updates',
    () async {
      final first = job('first', order: 0);
      final second = job('second', order: 1);
      final third = job('third', order: 2);
      await storage.addAll([third, first, second]);
      await storage.update(first.copyWith(progress: const Some(10)));
      expect((await storage.getAllPendingJobs()).map((job) => job.id), [
        'first',
        'second',
        'third',
      ]);
      expect((await storage.watchPendingJobs().first).map((job) => job.id), [
        'first',
        'second',
        'third',
      ]);
    },
  );

  test(
    'pending queue excludes processing, recovery, and completed jobs',
    () async {
      await storage.addAll([
        job('running', order: 0, status: .running),
        job('completed', order: 1, status: .completed),
        job('recovery', order: 2, status: .actionRequired),
        job('pending', order: 3),
      ]);
      expect((await storage.getAllPendingJobs()).map((job) => job.id), [
        'pending',
      ]);
      expect((await storage.watchPendingJobs().first).map((job) => job.id), [
        'pending',
      ]);
    },
  );
  test(
    'interrupted jobs restart with fresh session and progress metadata',
    () async {
      final interruptedStatuses = <JobStatus>[
        .pending,
        .preparing,
        .ready,
        .running,
        .cleaning,
      ];
      final interrupted = [
        for (final (index, status) in interruptedStatuses.indexed)
          job(status.name, order: index, status: status).copyWith(
            sessionId: const Some(42),
            progress: const Some(500),
            duration: const Some(1000),
          ),
      ];
      await storage.addAll(interrupted);
      final fixedJobs = await storage.fixInvalidJobs();
      expect(fixedJobs, hasLength(interrupted.length));
      for (final original in interrupted) {
        final fixed = (await storage.get(original.id))!;
        expect(fixed.status, JobStatus.pending);
        expect(fixed.sessionId, isNull);
        expect(fixed.progress, isNull);
        expect(fixed.duration, isNull);
        expect(fixed.createdAt, original.createdAt);
        expect(fixed.command, original.command);
        expect(fixed.inputFilePath, original.inputFilePath);
      }
      expect(
        (await storage.getAllPendingJobs()).map((job) => job.id),
        interruptedStatuses.map((status) => status.name),
      );
    },
  );

  test(
    'stopping jobs keep the queue and background service occupied',
    () async {
      await storage.add(job('stopping', order: 0, status: .stopping));
      expect(
        (await storage.getAllRunningJobs()).single.status,
        JobStatus.stopping,
      );
      expect(
        (await storage.watchRunningJobs().first).single.status,
        JobStatus.stopping,
      );
      expect(await storage.watchIsJobPendingOrProcessing().first, isTrue);
      expect(await storage.getAllPendingJobs(), isEmpty);
      expect(await storage.watchCompletedJobs().first, isEmpty);
    },
  );

  test('restart recovery preserves an interrupted stop request', () async {
    await storage.add(
      job('stopping', order: 0, status: .stopping).copyWith(
        sessionId: const Some(42),
        progress: const Some(500),
        duration: const Some(1000),
        executionId: const Some('previous-process'),
      ),
    );
    expect((await storage.get('stopping'))!.executionId, isNull);
    final repaired = (await storage.fixInvalidJobs()).single;
    expect(repaired.status, JobStatus.cancelled);
    expect(repaired.sessionId, isNull);
    expect(repaired.progress, isNull);
    expect(repaired.duration, isNull);
    expect(await storage.getAllPendingJobs(), isEmpty);
    expect(await storage.watchIsJobPendingOrProcessing().first, isFalse);
    expect(
      (await storage.watchCompletedJobs().first).single.status,
      JobStatus.cancelled,
    );
  });

  test(
    'restart recovery preserves saved outputs and completed history',
    () async {
      final preservedStatuses = <JobStatus>[
        .actionRequired,
        .completed,
        .failed,
        .cancelled,
      ];
      final preserved = [
        for (final (index, status) in preservedStatuses.indexed)
          job(status.name, order: index, status: status).copyWith(
            sessionId: const Some(42),
            progress: const Some(1000),
            convertedFilePath: Some('/recovery/${status.name}.mp3'),
          ),
      ];
      await storage.addAll(preserved);
      expect(await storage.fixInvalidJobs(), isEmpty);
      for (final original in preserved) {
        expect((await storage.get(original.id))!.toJson(), original.toJson());
      }
    },
  );
}

ConvertJob job(String id, {required int order, JobStatus status = .pending}) {
  final createdAt = DateTime(2026, 9, 30).add(Duration(seconds: order));
  return ConvertJob(
    id: id,
    inputFilePath: '/input/$id.wav',
    outputFileName: '$id.mp3',
    outputExtension: 'mp3',
    outputDirectoryPath: '/output',
    command: 'test-command',
    convertedFilePath: '/temporary/$id.mp3',
    createdAt: createdAt,
    updatedAt: createdAt,
    status: status,
  );
}
