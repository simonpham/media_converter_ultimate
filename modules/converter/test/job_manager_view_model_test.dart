import 'dart:async';

import 'package:converter/converter.dart';
import 'package:core_storage_base/core_storage_base.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_utils/platform_utils.dart';
import 'package:utils/utils.dart';

void main() {
  late MemoryJobStorage storage;
  late FakeRunner runner;
  late FakeFiles files;
  late MemorySettings settings;
  late JobManagerViewModel model;

  setUp(() {
    storage = MemoryJobStorage();
    runner = FakeRunner();
    files = FakeFiles();
    settings = MemorySettings();
    injector.registerSingleton<ConvertJobStorage>(storage);
    injector.registerSingleton<JobRunnerService>(runner);
    injector.registerSingleton<FileService>(files);
    injector.registerSingleton<SettingsBox>(settings);
    injector.registerSingleton<LogData>(MemoryLogs());
    model = JobManagerViewModel();
  });

  tearDown(() async {
    model.dispose();
    await runner.close();
    await injector.reset();
  });

  test(
    'overlapping additions start a job once and respect the concurrency limit',
    () async {
      runner.startGate = Completer<void>();
      final firstAdd = model.addJobs([job('first')]);
      await waitFor(() => runner.started.isNotEmpty);
      final secondAdd = model.addJobs([job('second')]);
      await Future<void>.delayed(Duration.zero);
      expect(runner.started, ['first']);
      runner.startGate!.complete();
      await Future.wait([firstAdd, secondAdd]);
      expect(runner.started, ['first']);
      expect(storage.jobs['second']!.status, JobStatus.pending);
    },
  );

  test(
    'runner session is stored even before its first progress callback',
    () async {
      await model.addJobs([job('first')]);
      final running = storage.jobs['first']!;
      expect(running.sessionId, 1);
      expect(running.status, JobStatus.running);
      await model.removeRunningJob(running);
      expect(runner.stopped, [1]);
    },
  );

  test(
    'a stale stop action cannot cancel a new attempt or completed output',
    () async {
      await model.addJobs([job('first')]);
      final original = storage.jobs['first']!;
      storage.jobs['first'] = original.copyWith(sessionId: const Some(2));
      await model.removeRunningJob(original);
      expect(runner.stopped, isEmpty);
      final current = storage.jobs['first']!;
      storage.jobs['first'] = current.copyWith(status: const Some(.completed));
      await model.removeRunningJob(current);
      expect(runner.stopped, isEmpty);
    },
  );

  test(
    'restart joins the queue while another conversion uses the slot',
    () async {
      await model.addJobs([job('first')]);
      final failed = job('retry', status: .failed).copyWith(
        sessionId: const Some(42),
        progress: const Some(900),
        duration: const Some(1000),
      );
      storage.jobs[failed.id] = failed;
      await model.restartJob(failed);
      expect(runner.started, ['first']);
      final queued = storage.jobs[failed.id]!;
      expect(queued.status, JobStatus.pending);
      expect(queued.sessionId, isNull);
      expect(queued.progress, isNull);
      expect(queued.duration, isNull);
    },
  );

  test(
    'startup exceptions mark failure and advance to the next pending job',
    () async {
      runner.failStarts.add('first');
      await model.addJobs([job('first'), job('second')]);
      expect(storage.jobs['first']!.status, JobStatus.failed);
      expect(storage.jobs['second']!.status, JobStatus.running);
      expect(runner.started, ['first', 'second']);
    },
  );

  for (final status in <JobStatus>[.failed, .cancelled]) {
    test('short ${status.name} runs advance without exporting', () async {
      runner.returnStatuses['first'] = status;
      await model.addJobs([job('first'), job('second')]);
      expect(storage.jobs['first']!.status, status);
      expect(storage.jobs['second']!.status, JobStatus.running);
      expect(files.moveAttempts, 0);
      expect(settings.successConversionCount, 0);
    });
  }

  test('short successful runs export once without another callback', () async {
    runner.returnStatuses['first'] = .cleaning;
    await model.addJobs([job('first'), job('second')]);
    expect(storage.jobs['first']!.status, JobStatus.completed);
    expect(storage.jobs['second']!.status, JobStatus.running);
    expect(files.moveAttempts, 1);
    expect(settings.successConversionCount, 1);
    runner.emit(storage.jobs['first']!.copyWith(status: const Some(.cleaning)));
    await flushEvents();
    expect(files.moveAttempts, 1);
    expect(settings.successConversionCount, 1);
  });

  test(
    'export failure keeps a recovery copy and starts the next queued job',
    () async {
      files.moveFailures.add(const DirectoryNotWritableFailure('/output'));
      await model.addJobs([job('first'), job('second')]);
      runner.emit(
        storage.jobs['first']!.copyWith(status: const Some(.cleaning)),
      );
      await waitFor(() => runner.started.length == 2);
      final recovery = storage.jobs['first']!;
      expect(recovery.status, JobStatus.actionRequired);
      expect(recovery.convertedFilePath, '/recovery/first.mp3');
      expect(storage.jobs['second']!.status, JobStatus.running);
    },
  );

  test(
    'late callbacks cannot overwrite a recovery copy or export it twice',
    () async {
      files.moveFailures.add(const DirectoryNotWritableFailure('/output'));
      await model.addJobs([job('first')]);
      final original = storage.jobs['first']!;
      runner.emit(original.copyWith(status: const Some(.cleaning)));
      await waitFor(() => storage.jobs['first']!.status == .actionRequired);
      runner.emit(original.copyWith(status: const Some(.running)));
      runner.emit(original.copyWith(status: const Some(.cleaning)));
      await flushEvents();
      expect(storage.jobs['first']!.convertedFilePath, '/recovery/first.mp3');
      expect(storage.jobs['first']!.status, JobStatus.actionRequired);
      expect(files.moveAttempts, 1);
    },
  );

  test(
    'duplicate completion callbacks finalize and count success once',
    () async {
      await model.addJobs([job('first')]);
      final completed = storage.jobs['first']!.copyWith(
        status: const Some(.cleaning),
      );
      runner.emit(completed);
      runner.emit(completed);
      await waitFor(() => storage.jobs['first']!.status == .completed);
      await flushEvents();
      expect(files.moveAttempts, 1);
      expect(files.cleanedInputs, ['first']);
      expect(settings.successConversionCount, 1);
    },
  );

  test(
    'completed jobs retain their state when an old callback arrives',
    () async {
      await model.addJobs([job('first')]);
      final original = storage.jobs['first']!;
      runner.emit(original.copyWith(status: const Some(.cleaning)));
      await waitFor(() => storage.jobs['first']!.status == .completed);
      final completed = storage.jobs['first'];
      runner.emit(
        original.copyWith(
          status: const Some(.running),
          progress: const Some(1),
        ),
      );
      await flushEvents();
      expect(storage.jobs['first'], same(completed));
    },
  );

  test('callbacks do not recreate a removed history entry', () async {
    final removed = job('removed', status: .completed);
    storage.jobs[removed.id] = removed;
    await model.removeJob(removed);
    runner.emit(removed.copyWith(status: const Some(.running)));
    await flushEvents();
    expect(storage.jobs, isEmpty);
  });

  test('a second export failure reuses the saved output instead of copying it again', () async {
    files.moveFailures.addAll([
      const DirectoryNotWritableFailure('/output'),
      const DirectoryNotWritableFailure('/new-output'),
    ]);
    await model.addJobs([job('first')]);
    runner.emit(storage.jobs['first']!.copyWith(status: const Some(.cleaning)));
    await waitFor(() => storage.jobs['first']!.status == .actionRequired);
    final recovery = storage.jobs['first']!;
    await model.handleJobChooseAnotherPathAction(recovery, '/new-output');
    expect(storage.jobs['first']!.status, JobStatus.actionRequired);
    expect(storage.jobs['first']!.convertedFilePath, '/recovery/first.mp3');
    expect(files.recoveryCopies, 1);
  });

  test('a stale pending row cannot remove a job that has started', () async {
    final pending = job('first');
    await model.addJobs([pending]);
    final failure = await model.removeJob(pending);
    expect(failure, isA<InvalidStatusFailure>());
    expect(storage.jobs['first']!.status, JobStatus.running);
    expect(files.cleanedInputs, isEmpty);
  });

  test(
    'a stale retry action cannot overwrite an already restarted job',
    () async {
      final failed = job('retry', status: .failed);
      storage.jobs[failed.id] = failed;
      await model.restartJob(failed);
      await model.restartJob(failed);
      expect(runner.started, ['retry']);
      expect(storage.jobs['retry']!.status, JobStatus.running);
      expect(storage.jobs['retry']!.sessionId, 1);
    },
  );

  test(
    'old session callbacks cannot interrupt a retry during preparation',
    () async {
      final oldAttempt = job(
        'retry',
        status: .failed,
      ).copyWith(sessionId: const Some(42));
      storage.jobs[oldAttempt.id] = oldAttempt;
      runner.startGate = Completer<void>();
      final retry = model.restartJob(oldAttempt);
      await waitFor(() => runner.started.isNotEmpty);
      runner.emit(oldAttempt.copyWith(status: const Some(.cancelled)));
      await flushEvents();
      expect(storage.jobs['retry']!.status, JobStatus.preparing);
      runner.startGate!.complete();
      await retry;
      expect(storage.jobs['retry']!.status, JobStatus.running);
      expect(storage.jobs['retry']!.sessionId, 1);
    },
  );

  test(
    'simultaneous completions refill slots without duplicate starts',
    () async {
      settings.concurrencyLimit = 2;
      await model.addJobs([
        job('first'),
        job('second'),
        job('third'),
        job('fourth'),
      ]);
      runner.emit(
        storage.jobs['first']!.copyWith(status: const Some(.cleaning)),
      );
      runner.emit(
        storage.jobs['second']!.copyWith(status: const Some(.cleaning)),
      );
      await waitFor(() => runner.started.length == 4);
      await flushEvents();
      expect(runner.started, ['first', 'second', 'third', 'fourth']);
      expect(await storage.getAllRunningJobs(), hasLength(2));
    },
  );

  test('cancellation advances the queue and ignores late progress', () async {
    await model.addJobs([job('first'), job('second')]);
    final first = storage.jobs['first']!;
    runner.emit(first.copyWith(status: const Some(.cancelled)));
    await waitFor(() => runner.started.length == 2);
    runner.emit(first.copyWith(status: const Some(.running)));
    await flushEvents();
    expect(storage.jobs['first']!.status, JobStatus.cancelled);
    expect(storage.jobs['second']!.status, JobStatus.running);
  });

  test(
    'cleanup failure does not stall the rest of a successful batch',
    () async {
      files.failCleanup = true;
      await model.addJobs([job('first'), job('second')]);
      runner.emit(
        storage.jobs['first']!.copyWith(status: const Some(.cleaning)),
      );
      await waitFor(() => runner.started.length == 2);
      expect(storage.jobs['first']!.status, JobStatus.completed);
      expect(settings.successConversionCount, 1);
    },
  );

  test(
    'progress never moves backward to a previous preparation state',
    () async {
      await model.addJobs([job('first')]);
      final running = storage.jobs['first']!;
      runner.emit(running.copyWith(status: const Some(.ready)));
      await flushEvents();
      expect(storage.jobs['first']!.status, JobStatus.running);
    },
  );

  test(
    'a callback from another session cannot replace the active session',
    () async {
      await model.addJobs([job('first')]);
      final running = storage.jobs['first']!;
      runner.emit(
        running.copyWith(
          sessionId: const Some(42),
          status: const Some(.failed),
        ),
      );
      await flushEvents();
      expect(storage.jobs['first']!.status, JobStatus.running);
      expect(storage.jobs['first']!.sessionId, 1);
    },
  );

  test(
    'explicit recovery exports the saved copy after choosing a new folder',
    () async {
      files.moveFailures.add(const DirectoryNotWritableFailure('/output'));
      await model.addJobs([job('first')]);
      runner.emit(
        storage.jobs['first']!.copyWith(status: const Some(.cleaning)),
      );
      await waitFor(() => storage.jobs['first']!.status == .actionRequired);
      final recovery = storage.jobs['first']!;
      final failure = await model.handleJobChooseAnotherPathAction(
        recovery,
        '/new-output',
      );
      expect(failure, isNull);
      expect(storage.jobs['first']!.status, JobStatus.completed);
      expect(storage.jobs['first']!.outputDirectoryPath, '/new-output');
      expect(files.movedSources, [
        '/temporary/first.mp3',
        '/recovery/first.mp3',
      ]);
      expect(settings.successConversionCount, 1);
    },
  );
}

ConvertJob job(String id, {JobStatus status = .pending}) {
  final now = DateTime(2026, 9, 30);
  return ConvertJob(
    id: id,
    inputFilePath: '/input/$id.wav',
    outputFileName: '$id.mp3',
    outputExtension: 'mp3',
    outputDirectoryPath: '/output',
    command: 'test-command',
    convertedFilePath: '/temporary/$id.mp3',
    createdAt: now,
    updatedAt: now,
    status: status,
  );
}

Future<void> waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (condition()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail('The expected queue state was not reached');
}

Future<void> flushEvents() async {
  for (var iteration = 0; iteration < 20; iteration++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class MemorySettings implements SettingsBox {
  final values = <dynamic, dynamic>{};

  @override
  dynamic get(dynamic key, {required dynamic defaultValue}) =>
      values[key] ?? defaultValue;

  @override
  Future<void> put(dynamic key, dynamic value) async => values[key] = value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MemoryLogs implements LogData {
  final values = <dynamic, dynamic>{};

  @override
  dynamic get(dynamic key, {required dynamic defaultValue}) =>
      values[key] ?? defaultValue;

  @override
  Future<void> put(dynamic key, dynamic value) async => values[key] = value;

  @override
  Future<void> onDispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MemoryJobStorage implements ConvertJobStorage {
  final jobs = <String, ConvertJob>{};

  @override
  Future<Failure?> addAll(List<ConvertJob> items) async {
    for (final item in items) {
      jobs[item.id] = item;
    }
    return null;
  }

  @override
  Future<ConvertJob?> get(String id) async => jobs[id];

  @override
  Future<Failure?> update(ConvertJob item) async {
    jobs[item.id] = item;
    return null;
  }

  @override
  Future<Failure?> delete(String id) async {
    jobs.remove(id);
    return null;
  }

  @override
  Future<List<ConvertJob>> getAllPendingJobs() async =>
      jobs.values.where((job) => job.status.isQueued).toList();

  @override
  Future<List<ConvertJob>> getAllRunningJobs() async =>
      jobs.values.where((job) => job.status.isProcessing).toList();

  @override
  void onDispose() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRunner implements JobRunnerService {
  final updates = StreamController<ConvertJob>.broadcast();
  final logs = StreamController<JobLog>.broadcast();
  final started = <String>[];
  final stopped = <int?>[];
  final failStarts = <String>{};
  final returnStatuses = <String, JobStatus>{};
  Completer<void>? startGate;

  @override
  Stream<ConvertJob> get onJobUpdate => updates.stream;

  @override
  Stream<JobLog> get onLogUpdate => logs.stream;

  void emit(ConvertJob job) => updates.add(job);

  @override
  Future<ConvertJob> run(ConvertJob job) async {
    started.add(job.id);
    if (failStarts.contains(job.id)) {
      throw StateError('Unable to prepare input');
    }
    if (startGate != null) {
      await startGate!.future;
    }
    return job.copyWith(
      sessionId: Some(started.length),
      status: Some(returnStatuses[job.id] ?? .running),
    );
  }

  @override
  Future<bool> stop(ConvertJob job) async {
    stopped.add(job.sessionId);
    return true;
  }

  Future<void> close() async {
    await updates.close();
    await logs.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFiles implements FileService {
  final moveFailures = <Failure?>[];
  final movedSources = <String>[];
  final cleanedInputs = <String>[];
  int moveAttempts = 0;
  int recoveryCopies = 0;
  bool failCleanup = false;

  @override
  Future<bool> isFileExist(String path) async => false;

  @override
  Future<Failure?> moveConvertedFileToPath({
    required String convertedFilePath,
    required String outputFileName,
    required String outputFilePath,
  }) async {
    moveAttempts++;
    movedSources.add(convertedFilePath);
    return moveFailures.isEmpty ? null : moveFailures.removeAt(0);
  }

  @override
  Future<(String?, Failure?)> copyTempOutputFileToConverted({
    required String jobId,
    required String convertedFilePath,
  }) async {
    recoveryCopies++;
    return ('/recovery/$jobId.mp3', null);
  }

  @override
  Future<void> prepareConvertTempFolder({required String jobId}) async {}

  @override
  Future<void> cleanUpInputFile({required String jobId}) async {
    if (failCleanup) {
      throw StateError('Unable to clean cached input');
    }
    cleanedInputs.add(jobId);
  }

  @override
  Future<void> deleteFileAtPath(String convertedFilePath) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
