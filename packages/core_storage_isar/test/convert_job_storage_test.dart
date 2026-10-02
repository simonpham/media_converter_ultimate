import 'dart:async';
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
    'provider output location and staged recovery survive storage round trips',
    () async {
      final completed = job('provider', order: 0, status: .completed).copyWith(
        outputDirectoryPath: const Some('mcu-output://downloads'),
        outputUri: const Some('content://media/external/downloads/42'),
        outputFileName: const Some('provider (1).mp3'),
        outputStaged: const Some(true),
      );
      final staged = job('staged', order: 1, status: .cleaning).copyWith(
        convertedFilePath: const Some('/app/converted/staged.mp3'),
        outputStaged: const Some(true),
      );
      await storage.addAll([completed, staged, job('legacy', order: 2)]);
      expect(
        (await storage.get('provider'))!.outputLocation,
        completed.outputUri,
      );
      expect(
        (await storage.get('provider'))!.outputFileName,
        'provider (1).mp3',
      );
      expect((await storage.get('legacy'))!.outputUri, isNull);
      await storage.fixInvalidJobs();
      final recovered = (await storage.get('staged'))!;
      expect(recovered.status, JobStatus.actionRequired);
      expect(recovered.convertedFilePath, '/app/converted/staged.mp3');
      expect(recovered.outputStaged, isTrue);
      expect((await storage.getAllPendingJobs()).map((job) => job.id), [
        'legacy',
      ]);
      expect((await storage.get('provider'))!.toJson(), completed.toJson());
    },
  );

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

  test(
    'activity watcher follows every processing and terminal state',
    () async {
      final activity = StreamIterator(storage.watchIsJobPendingOrProcessing());
      try {
        expect(await next(activity), isFalse);
        var current = job('conversion', order: 0);
        await storage.add(current);
        expect(await next(activity), isTrue);
        for (final status in <JobStatus>[
          .preparing,
          .ready,
          .running,
          .cleaning,
          .stopping,
        ]) {
          current = current.copyWith(status: Some(status));
          await storage.update(current);
          expect(await next(activity), isTrue, reason: status.name);
        }
        current = current.copyWith(status: const Some(.cancelled));
        await storage.update(current);
        expect(await next(activity), isFalse);
        expect(await storage.watchIsJobPendingOrProcessing().first, isFalse);
        for (final status in <JobStatus>[
          .actionRequired,
          .completed,
          .failed,
        ]) {
          await storage.update(current.copyWith(status: Some(status)));
          expect(await storage.watchIsJobPendingOrProcessing().first, isFalse);
        }
        expect(await storage.count(), 1);
      } finally {
        await activity.cancel();
      }
    },
  );

  test(
    'large batches retain activity updates for native service retry',
    () async {
      final batch = [
        for (var index = 0; index < 1000; index++)
          job('batch-$index', order: index).copyWith(
            command: Some(
              List.filled(128, '-metadata title=large-batch').join(' '),
            ),
          ),
      ];
      final activity = StreamIterator(storage.watchIsJobPendingOrProcessing());
      try {
        expect(await next(activity), isFalse);
        await storage.addAll(batch);
        expect(await next(activity), isTrue);
        final running = batch.first.copyWith(status: const Some(.running));
        await storage.update(running);
        expect(await next(activity), isTrue);
        await storage.update(running.copyWith(progress: const Some(100)));
        expect(await next(activity), isTrue);
        // Completion of one job must not stop the service with others queued.
        await storage.update(running.copyWith(status: const Some(.completed)));
        expect(await next(activity), isTrue);
        await storage.addAll([
          for (final queued in batch.skip(1))
            queued.copyWith(status: const Some(.completed)),
        ]);
        expect(await next(activity), isFalse);
        expect(await storage.count(), batch.length);
        expect((await storage.get(batch.last.id))!.command, batch.last.command);
      } finally {
        await activity.cancel();
      }
    },
  );

  test(
    'bounded pending query retains oldest-first order after updates',
    () async {
      final batch = [
        for (var index = 0; index < 1000; index++)
          job('batch-$index', order: index),
      ];
      await storage.addAll(batch.reversed.toList());
      await storage.update(batch.first.copyWith(progress: const Some(10)));
      expect((await storage.getNextPendingJobs(3)).map((job) => job.id), [
        'batch-0',
        'batch-1',
        'batch-2',
      ]);
      await storage.update(batch.first.copyWith(status: const Some(.running)));
      await storage.update(
        batch[1].copyWith(status: const Some(.actionRequired)),
      );
      expect((await storage.getNextPendingJobs(2)).map((job) => job.id), [
        'batch-2',
        'batch-3',
      ]);
      expect(await storage.getNextPendingJobs(0), isEmpty);
      expect(() => storage.getNextPendingJobs(-1), throwsRangeError);
      expect(await storage.getAllPendingJobs(), hasLength(998));
      expect(await storage.count(), 1000);
    },
  );

  test('clear history returns exactly the finished IDs removed', () async {
    await storage.addAll([
      for (final (index, status) in JobStatus.values.indexed)
        job(status.name, order: index, status: status),
    ]);
    expect(
      await storage.removeAllFinishedJobs(),
      unorderedEquals([
        'completed',
        'failed',
        'cancelled',
      ]),
    );
    for (final status in JobStatus.values) {
      expect(
        await storage.get(status.name),
        status.isDone ? isNull : isNotNull,
      );
    }
    expect(await storage.removeAllFinishedJobs(), isEmpty);
  });

  test(
    'age-based history clear preserves recent and unfinished jobs',
    () async {
      final now = DateTime.now();
      await storage.addAll([
        for (final (index, status) in JobStatus.values.indexed)
          for (final age in [1, 20])
            job('$age-${status.name}', order: index, status: status).copyWith(
              updatedAt: Some(now.subtract(Duration(days: age))),
            ),
      ]);
      expect(
        await storage.removeOlderFinishedJobs(7),
        unorderedEquals([
          '20-completed',
          '20-failed',
          '20-cancelled',
        ]),
      );
      for (final status in JobStatus.values) {
        expect(await storage.get('1-${status.name}'), isNotNull);
        expect(
          await storage.get('20-${status.name}'),
          status.isDone ? isNull : isNotNull,
        );
      }
      expect(await storage.removeOlderFinishedJobs(30), isEmpty);
      expect(() => storage.removeOlderFinishedJobs(-1), throwsRangeError);
    },
  );

  test('count watcher follows inserts, updates and deletions', () async {
    final counts = StreamIterator(storage.watchJobCount());
    try {
      expect(await next(counts), 0);
      await storage.addAll([job('first', order: 0), job('second', order: 1)]);
      expect(await next(counts), 2);
      await storage.update(job('first', order: 0, status: .completed));
      expect(await next(counts), 2);
      await storage.delete('second');
      expect(await next(counts), 1);
      await storage.removeAllFinishedJobs();
      expect(await next(counts), 0);
    } finally {
      await counts.cancel();
    }
  });
}

Future<T> next<T>(StreamIterator<T> iterator) async {
  expect(await iterator.moveNext().timeout(const Duration(seconds: 5)), isTrue);
  return iterator.current;
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
