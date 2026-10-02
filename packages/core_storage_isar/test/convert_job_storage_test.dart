import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:core/core.dart';
import 'package:core_storage_base/core_storage_base.dart';
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
    'startup repair cannot recreate a job deleted before its transaction',
    () async {
      final original = job('removed', order: 0, status: .running);
      await storage.add(original);
      final gated = _GatedIsar(isar);
      final repairing = ConvertJobIsarStorage(isar: gated).fixInvalidJobs();
      await gated.entered.future.timeout(const Duration(seconds: 5));
      try {
        expect(await storage.delete(original.id), isNull);
      } finally {
        gated.release.complete();
      }
      final repaired = await repairing;
      expect(await storage.get(original.id), isNull);
      expect(repaired, isEmpty);
    },
  );

  test(
    'startup repair preserves a completion committed before its transaction',
    () async {
      final original = job(
        'completed-during-repair',
        order: 0,
        status: .running,
      );
      await storage.add(original);
      final gated = _GatedIsar(isar);
      final repairing = ConvertJobIsarStorage(isar: gated).fixInvalidJobs();
      await gated.entered.future.timeout(const Duration(seconds: 5));
      Map<String, dynamic>? committed;
      try {
        await storage.update(
          original.copyWith(
            status: const .new(.completed),
            outputUri: const .new('content://media/downloads/42'),
            outputFileName: const .new('published.mp3'),
            sessionId: const .new(42),
            progress: const .new(1000),
          ),
        );
        committed = (await storage.get(original.id))!.toJson();
      } finally {
        gated.release.complete();
      }
      expect(await repairing, isEmpty);
      expect((await storage.get(original.id))!.toJson(), committed);
    },
  );

  test(
    'startup repair uses newly committed interrupted job settings',
    () async {
      final original = job(
        'changed-during-repair',
        order: 0,
        status: .preparing,
      );
      await storage.add(original);
      final gated = _GatedIsar(isar);
      final repairing = ConvertJobIsarStorage(isar: gated).fixInvalidJobs();
      await gated.entered.future.timeout(const Duration(seconds: 5));
      try {
        await storage.update(
          original.copyWith(
            status: const .new(.running),
            outputFileName: const .new('renamed.mp3'),
            outputDirectoryPath: const .new('/chosen'),
            inputFilePath: const .new('/input/owned.wav'),
            command: const .new('changed trim command'),
            sessionId: const .new(42),
            progress: const .new(500),
          ),
        );
      } finally {
        gated.release.complete();
      }
      final repaired = (await repairing).single;
      expect(repaired.outputFileName, 'renamed.mp3');
      expect(repaired.outputDirectoryPath, '/chosen');
      expect(repaired.inputFilePath, '/input/owned.wav');
      expect(repaired.command, 'changed trim command');
      expect(repaired.status, JobStatus.pending);
      expect(repaired.sessionId, isNull);
      expect(repaired.progress, isNull);
      expect((await storage.get(original.id))!.toJson(), repaired.toJson());
    },
  );

  test('failed repair transaction rolls back and reports the error', () async {
    final original = job('rollback', order: 0, status: .running).copyWith(
      sessionId: const .new(42),
      progress: const .new(500),
    );
    await storage.add(original);
    final gated = _GatedIsar(isar, failAfterWrite: true);
    final repairing = ConvertJobIsarStorage(isar: gated).fixInvalidJobs();
    final failed = expectLater(repairing, throwsStateError);
    await gated.entered.future.timeout(const Duration(seconds: 5));
    gated.release.complete();
    await failed;
    expect((await storage.get(original.id))!.toJson(), original.toJson());
    final retried = (await storage.fixInvalidJobs()).single;
    expect(retried.status, JobStatus.pending);
    expect(retried.sessionId, isNull);
  });

  test(
    'repair of a closed database reports failure and preserves pending data',
    () async {
      final original = job('closed-repair', order: 0, status: .running);
      await storage.add(original);
      await isar.close();
      try {
        await expectLater(storage.fixInvalidJobs(), throwsA(isA<IsarError>()));
      } finally {
        isar = await Isar.open(
          [IsarConvertJobSchema],
          directory: temporaryDirectory.path,
          name: 'queue-test',
        );
        storage = ConvertJobIsarStorage(isar: isar);
      }
      expect((await storage.get(original.id))!.toJson(), original.toJson());
    },
  );

  test(
    'dependency disposal waits for an active database transaction',
    () async {
      final owner = GetIt.asNewInstance();
      owner.registerSingleton<ConvertJobStorage>(storage);
      final entered = Completer<void>();
      final release = Completer<void>();
      final stored = job('during-disposal', order: 0);
      final writing = isar.writeTxn(() async {
        await isar.isarConvertJobs.put(stored.toIsarModel());
        entered.complete();
        await release.future;
      });
      await entered.future;
      var disposed = false;
      var closedAfterDisposal = false;
      final disposing = owner.reset().then((_) => disposed = true);
      try {
        await Future<void>.delayed(Duration.zero);
        expect(disposed, isFalse);
      } finally {
        release.complete();
        await writing;
        await disposing;
        await Future<void>.delayed(Duration.zero);
        closedAfterDisposal = !isar.isOpen;
        if (closedAfterDisposal) {
          isar = await Isar.open(
            [IsarConvertJobSchema],
            directory: temporaryDirectory.path,
            name: 'queue-test',
          );
        }
      }
      expect(closedAfterDisposal, isTrue);
      storage = ConvertJobIsarStorage(isar: isar);
      expect((await storage.get(stored.id))!.toJson(), stored.toJson());
    },
  );

  test(
    'dependency disposal tolerates a database that already closed',
    () async {
      final owner = GetIt.asNewInstance();
      owner.registerSingleton<ConvertJobStorage>(storage);
      await isar.close();
      try {
        await expectLater(owner.reset(), completes);
      } finally {
        isar = await Isar.open(
          [IsarConvertJobSchema],
          directory: temporaryDirectory.path,
          name: 'queue-test',
        );
      }
    },
  );

  test(
    'failed batch save keeps history and accepted retry survives reopening',
    () async {
      final previous = job('previous', order: 0, status: .completed);
      final batch = [job('first', order: 1), job('second', order: 2)];
      await storage.add(previous);
      await isar.close();
      await expectLater(storage.addAll(batch), throwsA(isA<IsarError>()));

      Future<void> reopen() async {
        isar = await Isar.open(
          [IsarConvertJobSchema],
          directory: temporaryDirectory.path,
          name: 'queue-test',
        );
        storage = ConvertJobIsarStorage(isar: isar);
      }

      await reopen();
      expect(await storage.count(), 1);
      expect((await storage.get(previous.id))!.toJson(), previous.toJson());
      expect(await storage.getAllPendingJobs(), isEmpty);
      expect(await storage.addAll(batch), isNull);
      await isar.close();
      await reopen();
      expect(await storage.count(), 3);
      expect(
        (await storage.getAllPendingJobs()).map((job) => job.toJson()),
        batch.map((job) => job.toJson()),
      );
      expect((await storage.get(previous.id))!.toJson(), previous.toJson());
    },
  );

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

/// Delays transaction entry while retaining real native Isar queries and writes.
/// The competing commit finishes before repair acquires its write transaction.
class _GatedIsar(final Isar delegate, {final bool failAfterWrite = false})
    implements Isar {
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  IsarCollection<T> collection<T>() => delegate.collection<T>();
  @override
  Future<T> writeTxn<T>(
    Future<T> Function() callback, {
    bool silent = false,
  }) async {
    entered.complete();
    await release.future;
    return delegate.writeTxn(() async {
      final result = await callback();
      if (failAfterWrite) throw StateError('Repair commit rejected');
      return result;
    }, silent: silent);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
