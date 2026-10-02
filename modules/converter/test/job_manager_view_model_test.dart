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
  late MemoryLogs logs;
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
    logs = MemoryLogs();
    injector.registerSingleton<LogData>(logs);
    model = JobManagerViewModel();
  });

  tearDown(() async {
    model.dispose();
    await runner.close();
    await injector.reset();
  });

  test(
    'enqueue reports a failed batch save before starting or cleaning files',
    () async {
      storage.addFailure = const Failure('Cannot save batch');
      await expectLater(
        model.enqueueJobs([job('first')]),
        throwsA(isA<FailedToQueueJobsFailure>()),
      );
      expect(storage.jobs, isEmpty);
      expect(runner.started, isEmpty);
      expect(files.cleanedInputs, isEmpty);
      expect(files.deletedStages, isEmpty);
      storage.addFailure = null;
      await model.enqueueJobs([job('retry')]);
      await waitFor(() => runner.started.isNotEmpty);
      expect(runner.started, ['retry']);
    },
  );

  test(
    'enqueue resolves after saving without waiting for native startup',
    () async {
      runner.startGate = Completer<void>();
      await model.enqueueJobs([job('first'), job('second')]);
      expect(storage.jobs.keys, ['first', 'second']);
      await waitFor(() => runner.started.isNotEmpty);
      expect(storage.jobs['first']!.status, JobStatus.preparing);
      expect(storage.jobs['second']!.status, JobStatus.pending);
      expect(files.cleanedInputs, isEmpty);
      runner.startGate!.complete();
      await waitFor(() => storage.jobs['first']!.status == .running);
    },
  );

  test('native preparation failure after enqueue preserves accepted inputs and advances', () async {
    runner.failStarts.add('first');
    await model.enqueueJobs([job('first'), job('second')]);
    await waitFor(() => storage.jobs['second']?.status == .running);
    expect(storage.jobs['first']!.status, JobStatus.failed);
    expect(runner.started, ['first', 'second']);
    expect(files.cleanedInputs, isEmpty);
    expect(files.deletedStages, isEmpty);
  });

  test('clear history removes finished logs and preserves outputs', () async {
    for (final status in JobStatus.values) {
      storage.jobs[status.name] = job(status.name, status: status);
      logs.values[status.name] = '${status.name} log';
    }
    expect(await model.clearFinishedJobs(.everything), isNull);
    for (final status in JobStatus.values) {
      expect(storage.jobs.containsKey(status.name), !status.isDone);
      expect(logs.values.containsKey(status.name), !status.isDone);
    }
    expect(logs.cleared, unorderedEquals(['completed', 'failed', 'cancelled']));
    expect(files.deletedOutputs, isEmpty);
    expect(files.deletedStages, isEmpty);
    expect(files.cleanedInputs, isEmpty);
  });

  test('age-based history clear removes only expired finished logs', () async {
    final now = DateTime.now();
    for (final status in JobStatus.values) {
      for (final age in [1, 20]) {
        final id = '$age-${status.name}';
        storage.jobs[id] = job(id, status: status).copyWith(
          updatedAt: Some(now.subtract(Duration(days: age))),
        );
        logs.values[id] = '$id log';
      }
    }
    expect(await model.clearFinishedJobs(.olderThan7Days), isNull);
    expect(
      logs.cleared,
      unorderedEquals([
        '20-completed',
        '20-failed',
        '20-cancelled',
      ]),
    );
    expect(logs.values.keys, unorderedEquals(storage.jobs.keys));
    expect(files.deletedOutputs, isEmpty);
    expect(files.deletedStages, isEmpty);
    expect(files.cleanedInputs, isEmpty);
  });

  test('failed history transaction leaves logs intact', () async {
    storage.failHistoryClear = true;
    storage.jobs['completed'] = job('completed', status: .completed);
    logs.values['completed'] = 'saved log';
    expect(
      await model.clearFinishedJobs(.everything),
      isA<FailedToClearJobsFailure>(),
    );
    expect(storage.jobs.keys, ['completed']);
    expect(logs.values['completed'], 'saved log');
    expect(logs.cleared, isEmpty);
  });

  test(
    'log cleanup failure does not reverse successful history deletion',
    () async {
      storage.jobs['completed'] = job('completed', status: .completed);
      logs.values['completed'] = 'saved log';
      logs.failCleanup = true;
      expect(await model.clearFinishedJobs(.everything), isNull);
      expect(storage.jobs, isEmpty);
      expect(logs.values['completed'], 'saved log');
      expect(files.deletedOutputs, isEmpty);
      expect(files.deletedStages, isEmpty);
    },
  );

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

  for (final savedLimit in [0, -1, 'three']) {
    test('queue starts safely with invalid saved limit $savedLimit', () async {
      settings.values[JobRunnerSettings.concurrencyLimit] = savedLimit;
      await model.addJobs([job('first'), job('second')]);
      expect(runner.started, ['first']);
      expect(storage.jobs['second']!.status, JobStatus.pending);
    });
  }

  test(
    'large queue fetches only available slots and refills oldest work',
    () async {
      settings.concurrencyLimit = 2;
      await model.addJobs([
        for (var index = 0; index < 1000; index++) job('batch-$index'),
      ]);
      expect(runner.started, ['batch-0', 'batch-1']);
      expect(storage.pendingQueryLimits, [2]);
      expect(storage.pendingResultCounts, [2]);
      runner.emit(
        storage.jobs['batch-0']!.copyWith(status: const Some(.cancelled)),
      );
      await waitFor(() => runner.started.length == 3);
      await flushEvents();
      expect(runner.started, ['batch-0', 'batch-1', 'batch-2']);
      expect(storage.pendingQueryLimits, [2, 1]);
      expect(storage.pendingResultCounts, [2, 1]);
      expect(await storage.getAllPendingJobs(), hasLength(997));
      expect(await storage.getAllRunningJobs(), hasLength(2));
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
    'preparation stop retains the queue slot until acknowledgement',
    () async {
      runner.startGate = Completer<void>();
      runner.stopGate = Completer<void>();
      runner.returnStatuses['first'] = .cancelled;
      final adding = model.addJobs([job('first'), job('second')]);
      await waitFor(() => runner.started.isNotEmpty);
      final preparing = storage.jobs['first']!;
      final executionId = model.activeExecutionId('first');
      final stopping = model.removeRunningJob(
        preparing,
        executionId: executionId,
      );
      await waitFor(() => runner.stopped.isNotEmpty);
      final repeated = model.removeRunningJob(
        preparing,
        executionId: executionId,
      );
      await flushEvents();
      expect(storage.jobs['first']!.status, JobStatus.stopping);
      expect(runner.started, ['first']);
      expect(runner.stopped, [null]);
      runner.startGate!.complete();
      runner.stopGate!.complete();
      await Future.wait([adding, stopping, repeated]);
      expect(storage.jobs['first']!.status, JobStatus.cancelled);
      expect(runner.started, ['first', 'second']);
      expect(files.moveAttempts, 0);
    },
  );

  test('Stop before runner registration waits for that execution', () async {
    storage.preparingCommitGate = Completer<void>();
    runner.startGate = Completer<void>();
    runner.stopGate = Completer<void>();
    final adding = model.addJobs([job('first')]);
    await waitFor(() => storage.jobs['first']?.status == .preparing);
    final preparing = storage.jobs['first']!;
    final stopping = model.removeRunningJob(preparing);
    await flushEvents();
    expect(runner.started, isEmpty);
    expect(runner.stopped, isEmpty);
    storage.preparingCommitGate!.complete();
    await waitFor(() => runner.stopped.isNotEmpty);
    expect(storage.jobs['first']!.status, JobStatus.stopping);
    runner.startGate!.complete();
    runner.stopGate!.complete();
    await Future.wait([adding, stopping]);
    expect(runner.started, ['first']);
    expect(runner.stopped, [null]);
    expect(storage.jobs['first']!.status, JobStatus.cancelled);
  });

  test(
    'a stale preparation Stop and null-session update cannot affect retry',
    () async {
      runner.startGate = Completer<void>();
      final adding = model.addJobs([job('first')]);
      await waitFor(() => runner.started.isNotEmpty);
      final old = storage.jobs['first']!;
      final oldExecution = model.activeExecutionId('first');
      runner.startGate!.complete();
      await adding;
      runner.emit(
        storage.jobs['first']!.copyWith(status: const Some(.cancelled)),
      );
      await waitFor(() => model.activeExecutionId('first') == null);
      await model.restartJob(storage.jobs['first']!);
      final current = storage.jobs['first']!;
      expect(current.executionId, isNot(oldExecution));
      await model.removeRunningJob(old, executionId: oldExecution);
      runner.emit(old.copyWith(status: const Some(.cancelled)));
      await flushEvents();
      expect(runner.stopped, isEmpty);
      expect(storage.jobs['first']!.status, JobStatus.running);
      expect(storage.jobs['first']!.sessionId, current.sessionId);
    },
  );

  test(
    'same preparation Stop remains valid after the encoder gets an ID',
    () async {
      runner.startGate = Completer<void>();
      final adding = model.addJobs([job('first')]);
      await waitFor(() => runner.started.isNotEmpty);
      final preparing = storage.jobs['first']!;
      final executionId = model.activeExecutionId('first');
      runner.startGate!.complete();
      await adding;
      await model.removeRunningJob(preparing, executionId: executionId);
      expect(runner.stopped, [1]);
      expect(storage.jobs['first']!.status, JobStatus.cancelled);
    },
  );

  test(
    'an unacknowledged stop restores running and keeps the queue slot',
    () async {
      runner.stopResult = false;
      await model.addJobs([job('first'), job('second')]);
      await model.removeRunningJob(storage.jobs['first']!);
      expect(storage.jobs['first']!.status, JobStatus.running);
      expect(storage.jobs['second']!.status, JobStatus.pending);
      expect(runner.started, ['first']);
      expect(files.moveAttempts, 0);
    },
  );

  test(
    'provider URI is committed before acknowledging and deleting the stage',
    () async {
      files.returnedOutput = const ExportedFile(
        location: 'content://media/downloads/42',
        name: 'actual.mp3',
      );
      files.onAcknowledge = () {
        expect(storage.jobs['first']!.status, JobStatus.completed);
        expect(
          storage.jobs['first']!.outputUri,
          'content://media/downloads/42',
        );
        expect(files.deletedStages, isEmpty);
      };
      await model.addJobs([job('first')]);
      runner.emit(
        storage.jobs['first']!.copyWith(status: const Some(.cleaning)),
      );
      await waitFor(() => storage.jobs['first']!.status == .completed);
      await flushEvents();
      expect(storage.jobs['first']!.outputFileName, 'actual.mp3');
      expect(files.acknowledged, ['first']);
      expect(files.deletedStages, ['/recovery/first.mp3']);
      await model.deleteOutputFile(storage.jobs['first']!);
      expect(files.deletedOutputs, ['content://media/downloads/42']);
    },
  );

  test(
    'failed job commit keeps export receipt and stage for restart recovery',
    () async {
      const exported = ExportedFile(
        location: 'content://media/downloads/42',
        name: 'actual.mp3',
      );
      files.returnedOutput = exported;
      storage.failCompletedCommit = true;
      await model.addJobs([job('first')]);
      runner.emit(
        storage.jobs['first']!.copyWith(status: const Some(.cleaning)),
      );
      await waitFor(() => files.moveAttempts == 1);
      await flushEvents();
      expect(storage.jobs['first']!.status, JobStatus.cleaning);
      expect(storage.jobs['first']!.outputStaged, isTrue);
      expect(files.acknowledged, isEmpty);
      expect(files.deletedStages, isEmpty);
      storage.failCompletedCommit = false;
      files.recoveredOutputs['first'] = exported;
      await model.restartPendingJobs();
      expect(storage.jobs['first']!.status, JobStatus.completed);
      expect(storage.jobs['first']!.outputUri, exported.location);
      expect(files.moveAttempts, 1);
      expect(runner.started, ['first']);
      expect(files.acknowledged, ['first']);
    },
  );

  test('retry export reuses the stage without running FFmpeg again', () async {
    files.moveFailures.add(const OutputFolderAccessExpiredFailure());
    await model.addJobs([job('first')]);
    runner.emit(storage.jobs['first']!.copyWith(status: const Some(.cleaning)));
    await waitFor(() => storage.jobs['first']!.status == .actionRequired);
    expect(await model.retryExport(storage.jobs['first']!), isNull);
    expect(files.recoveryCopies, 1);
    expect(files.moveAttempts, 2);
    expect(runner.started, ['first']);
  });

  test('successful completion wins a stop race and exports once', () async {
    runner.stopGate = Completer<void>();
    runner.stopResult = false;
    await model.addJobs([job('first')]);
    final current = storage.jobs['first']!;
    final stopping = model.removeRunningJob(current);
    await waitFor(() => runner.stopped.isNotEmpty);
    runner.emit(current.copyWith(status: const Some(.cleaning)));
    await waitFor(() => storage.jobs['first']!.status == .completed);
    runner.stopGate!.complete();
    await stopping;
    expect(storage.jobs['first']!.status, JobStatus.completed);
    expect(files.moveAttempts, 1);
    expect(settings.successConversionCount, 1);
  });

  test(
    'encoder metadata is retained while stop waits for acknowledgement',
    () async {
      runner.startGate = Completer<void>();
      runner.stopGate = Completer<void>();
      final adding = model.addJobs([job('first')]);
      await waitFor(() => runner.started.isNotEmpty);
      final preparing = storage.jobs['first']!;
      final stopping = model.removeRunningJob(preparing);
      await waitFor(() => runner.stopped.isNotEmpty);
      runner.emit(
        preparing.copyWith(
          sessionId: const Some(1),
          status: const Some(.running),
          progress: const Some(500),
          duration: const Some(1000),
        ),
      );
      await flushEvents();
      expect(storage.jobs['first']!.status, JobStatus.stopping);
      expect(storage.jobs['first']!.sessionId, 1);
      expect(storage.jobs['first']!.progress, 500);
      runner.startGate!.complete();
      runner.stopGate!.complete();
      await Future.wait([adding, stopping]);
      expect(storage.jobs['first']!.status, JobStatus.cancelled);
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
    'a failed preparation commit does not spin or retain execution state',
    () async {
      storage.updateFailure = const Failure('Commit failed');
      await expectLater(model.addJobs([job('first')]), throwsA(isA<Failure>()));
      await flushEvents();
      expect(runner.started, isEmpty);
      expect(storage.updateAttempts, 1);
      expect(model.activeExecutionId('first'), isNull);
      storage.updateFailure = null;
      await model.runJob(storage.jobs['first']!);
      expect(storage.jobs['first']!.status, JobStatus.running);
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
    'pending removal wins over a later startup without running deleted work',
    () async {
      final pending = job('removing');
      storage.jobs[pending.id] = pending;
      final gate = storage.nextReadGate = Completer<void>();
      final removing = model.removeJob(pending);
      final starting = model.runJob(pending);
      await flushEvents();
      gate.complete();
      expect(await removing, isNull);
      await starting;
      expect(runner.started, isEmpty);
      expect(storage.jobs, isEmpty);
      expect(files.cleanedInputs, ['removing']);
    },
  );

  test(
    'removing a pending startup candidate advances to the next job',
    () async {
      final first = job('removed');
      final second = job('next');
      storage.jobs[first.id] = first;
      final gate = storage.nextReadGate = Completer<void>();
      final removing = model.removeJob(first);
      final adding = model.addJobs([first, second]);
      await flushEvents();
      gate.complete();
      expect(await removing, isNull);
      await adding;
      await flushEvents();
      expect(storage.jobs.containsKey(first.id), isFalse);
      expect(runner.started, ['next']);
      expect(storage.jobs[second.id]!.status, JobStatus.running);
    },
  );

  test(
    'startup wins over a later removal without deleting its cached input',
    () async {
      final pending = job('starting');
      storage.jobs[pending.id] = pending;
      final gate = storage.nextReadGate = Completer<void>();
      final starting = model.runJob(pending);
      final removing = model.removeJob(pending);
      await flushEvents();
      gate.complete();
      await starting;
      expect(await removing, isA<InvalidStatusFailure>());
      expect(runner.started, ['starting']);
      expect(storage.jobs['starting']!.status, JobStatus.running);
      expect(files.cleanedInputs, isEmpty);
      expect(files.deletedStages, isEmpty);
    },
  );

  test('failed job deletion preserves its log and cached files', () async {
    final completed = job('kept', status: .completed);
    storage.jobs[completed.id] = completed;
    logs.values[completed.id] = 'Details for retry';
    storage.deleteFailure = const Failure('Cannot delete record');
    expect(await model.removeJob(completed), same(storage.deleteFailure));
    expect(storage.jobs[completed.id], same(completed));
    expect(logs.getLog(completed.id), 'Details for retry');
    expect(files.cleanedInputs, isEmpty);
    expect(files.deletedStages, isEmpty);
  });

  test(
    'simultaneous retries cannot restart the same native work twice',
    () async {
      final failed = job('retry', status: .failed);
      storage.jobs[failed.id] = failed;
      final gate = storage.nextReadGate = Completer<void>();
      final first = model.restartJob(failed);
      final second = model.restartJob(failed);
      await flushEvents();
      gate.complete();
      await Future.wait([first, second]);
      expect(runner.started, ['retry']);
      expect(storage.jobs['retry']!.status, JobStatus.running);
      expect(storage.jobs['retry']!.sessionId, 1);
    },
  );

  test(
    'failed retry commit is reported and does not block a later retry',
    () async {
      final failed = job('retry', status: .failed);
      storage.jobs[failed.id] = failed;
      const failure = Failure('Cannot save retry');
      storage.updateFailure = failure;
      await expectLater(model.restartJob(failed), throwsA(same(failure)));
      expect(storage.jobs[failed.id], same(failed));
      expect(runner.started, isEmpty);
      storage.updateFailure = null;
      await model.restartJob(failed);
      expect(runner.started, ['retry']);
      expect(storage.jobs[failed.id]!.status, JobStatus.running);
    },
  );

  test(
    'removal before retry cannot recreate a deleted history entry',
    () async {
      final completed = job('removed', status: .completed);
      storage.jobs[completed.id] = completed;
      final gate = storage.nextReadGate = Completer<void>();
      final removing = model.removeJob(completed);
      final restarting = model.restartJob(completed);
      await flushEvents();
      gate.complete();
      expect(await removing, isNull);
      await restarting;
      expect(storage.jobs, isEmpty);
      expect(runner.started, isEmpty);
    },
  );

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
        '/recovery/first.mp3',
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
  final cleared = <String>[];
  bool failCleanup = false;

  @override
  Future<void> clearLogs(Iterable<String> jobIds) async {
    if (failCleanup) throw StateError('Unable to clear logs');
    for (final id in jobIds) {
      values.remove(id);
      cleared.add(id);
    }
  }

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
  final pendingQueryLimits = <int>[];
  final pendingResultCounts = <int>[];
  Completer<void>? preparingCommitGate;
  Completer<void>? nextReadGate;
  Failure? deleteFailure;
  Failure? addFailure;
  Failure? updateFailure;
  int updateAttempts = 0;
  bool failCompletedCommit = false;
  bool failHistoryClear = false;

  @override
  Future<List<String>?> removeAllFinishedJobs() async => _clearHistory();

  @override
  Future<List<String>?> removeOlderFinishedJobs(int dayCount) async =>
      _clearHistory(cutoff: DateTime.now().subtract(Duration(days: dayCount)));

  List<String>? _clearHistory({DateTime? cutoff}) {
    if (failHistoryClear) return null;
    final removedIds = jobs.values
        .where(
          (job) =>
              job.status.isDone &&
              (cutoff == null || job.updatedAt.isBefore(cutoff)),
        )
        .map((job) => job.id)
        .toList();
    for (final id in removedIds) {
      jobs.remove(id);
    }
    return removedIds;
  }

  @override
  Future<Failure?> addAll(List<ConvertJob> items) async {
    if (addFailure != null) return addFailure;
    for (final item in items) {
      jobs[item.id] = item;
    }
    return null;
  }

  @override
  Future<ConvertJob?> get(String id) async {
    final snapshot = jobs[id];
    final gate = nextReadGate;
    nextReadGate = null;
    await gate?.future;
    return snapshot;
  }

  @override
  Future<Failure?> update(ConvertJob item) async {
    updateAttempts++;
    if (updateFailure != null) return updateFailure;
    if (failCompletedCommit && item.status == .completed) {
      return const Failure('commit failed');
    }
    jobs[item.id] = item;
    if (item.status == .preparing) await preparingCommitGate?.future;
    return null;
  }

  @override
  Future<Failure?> delete(String id) async {
    if (deleteFailure != null) return deleteFailure;
    jobs.remove(id);
    return null;
  }

  @override
  Future<List<ConvertJob>> getAllPendingJobs() async =>
      jobs.values.where((job) => job.status.isQueued).toList();

  @override
  Future<List<ConvertJob>> getNextPendingJobs(int limit) async {
    pendingQueryLimits.add(limit);
    final pending = (await getAllPendingJobs()).take(limit).toList();
    pendingResultCounts.add(pending.length);
    return pending;
  }

  @override
  Future<List<ConvertJob>> getAllRunningJobs() async =>
      jobs.values.where((job) => job.status.isProcessing).toList();

  @override
  Stream<List<ConvertJob>> watchActionRequiredJobs() => Stream.value(
    jobs.values.where((job) => job.status == .actionRequired).toList(),
  );

  @override
  Future<List<ConvertJob>> fixInvalidJobs() async {
    final fixed = jobs.values
        .where((job) => job.status == .cleaning && job.outputStaged)
        .map((job) => job.copyWith(status: const Some(.actionRequired)))
        .toList();
    for (final job in fixed) {
      jobs[job.id] = job;
    }
    return fixed;
  }

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
  Completer<void>? stopGate;
  bool stopResult = true;

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
    await stopGate?.future;
    return stopResult;
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
  ExportedFile? returnedOutput;
  void Function()? onAcknowledge;
  final acknowledged = <String>[];
  final deletedStages = <String>[];
  final deletedOutputs = <String>[];
  final recoveredOutputs = <String, ExportedFile>{};

  @override
  Future<bool> isFileExist(String path) async => false;

  @override
  Future<bool> outputExists(String destination, String name) async => false;

  @override
  Future<void> acknowledgeExport(String exportId) async {
    onAcknowledge?.call();
    acknowledged.add(exportId);
  }

  @override
  Future<ExportedFile?> recoverExport(String exportId) async =>
      recoveredOutputs[exportId];

  @override
  Future<(ExportedFile?, Failure?)> exportFile({
    required String exportId,
    required String source,
    required String destination,
    required String name,
  }) async {
    final failure = await moveConvertedFileToPath(
      convertedFilePath: source,
      outputFileName: name,
      outputFilePath: destination,
    );
    return failure == null
        ? (
            returnedOutput ??
                ExportedFile(location: join(destination, name), name: name),
            null,
          )
        : (null, failure);
  }

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
  Future<void> deleteFileAtPath(String convertedFilePath) async {
    deletedStages.add(convertedFilePath);
  }

  @override
  Future<void> deleteOutput(String location) async {
    deletedOutputs.add(location);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
