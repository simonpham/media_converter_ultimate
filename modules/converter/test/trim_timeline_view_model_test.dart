import 'dart:async';

import 'package:converter/converter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_utils/platform_utils.dart';

void main() {
  late _Preview preview;
  late TrimTimelineViewModel model;
  setUp(() {
    preview = _Preview();
    model = TrimTimelineViewModel(
      path: '/movie.mkv',
      session: preview,
      waveColor: '123456',
    );
  });
  tearDown(() async {
    model.dispose();
    await Future<void>.delayed(Duration.zero);
  });

  test(
    'timeline uses millisecond bounds and clamps seek/range helpers',
    () async {
      await model.initialize();
      model.seek(750);
      model.setStartAtCursor();
      model.nudge(1500);
      model.setEndAtCursor();
      expect(model.result.arguments, ['-ss', '0.750', '-t', '1.500']);
      model.seek(0);
      model.setEndAtCursor();
      expect(model.end, model.start + 1);
      model.nudge(-1000);
      expect(model.position, 0);
      model.nudge(1000000);
      expect(model.position, model.duration);
      expect(model.windowEnd, model.duration);
    },
  );

  test('zoomed waveform and cursor use the same bounded time window', () async {
    preview.information = const PreviewMediaInfo(
      Duration(minutes: 2),
      audioIndex: 1,
    );
    await model.initialize();
    model.seek(60000);
    await Future<void>.delayed(Duration.zero);
    expect(model.windowStart, 45000);
    expect(model.windowEnd, 75000);
    expect(preview.windows.last, (45000, 30000));
    model.zoom(true);
    await Future<void>.delayed(Duration.zero);
    expect(model.windowLength, 15000);
    expect(preview.windows.last, (model.windowStart, model.windowLength));
    model.nudge(100);
    await Future<void>.delayed(Duration.zero);
    expect(preview.windows.length, 3);
    model.zoom(false);
    model.zoom(false);
    expect(model.windowLength, 30000);
  });

  test('obsolete frame requests are coalesced and cannot replace the latest cursor', () async {
    preview.frameGate = Completer<void>();
    await model.initialize();
    model.seek(1500);
    model.seek(1600);
    expect(preview.frames, [0]);
    preview.frameGate!.complete();
    await Future<void>.delayed(Duration.zero);
    expect(preview.frames, [0, 1600]);
    expect(model.frame, 'frame-1600.png');
    expect(preview.maximumActiveFrames, 1);
  });

  test(
    'preview pauses on seek and ignores completion from the previous playback',
    () async {
      await model.initialize();
      await model.play();
      expect(model.playing, isTrue);
      preview.positionEvents.add(const Duration(seconds: 2));
      await Future<void>.delayed(Duration.zero);
      expect(model.position, 2000);
      model.seek(3500);
      preview.completeEvents.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(model.playing, isFalse);
      expect(model.position, 3500);
    },
  );

  test(
    'pause during audio preparation prevents later playback startup',
    () async {
      preview.playGate = Completer<void>();
      await model.initialize();
      final playing = model.play();
      expect(model.preparingAudio, isTrue);
      await model.pause();
      preview.playGate!.complete();
      await playing;
      expect(model.playing, isFalse);
      expect(model.preparingAudio, isFalse);
    },
  );

  test(
    'the end-of-file selection remains open for differing batch durations',
    () async {
      await model.initialize();
      expect(model.result.end, isNull);
      model.setRange(0, 4250);
      expect(model.result.end, const Duration(milliseconds: 4250));
    },
  );

  test(
    'discarding a preview while probing closes it without late notifications',
    () async {
      preview.inspectGate = Completer<void>();
      var notifications = 0;
      model.addListener(() => notifications++);
      final initializing = model.initialize();
      model.dispose();
      preview.inspectGate!.complete();
      await initializing;
      expect(preview.closed, isTrue);
      expect(notifications, 0);
      // Replace the disposed model so the common teardown disposes only once.
      model = TrimTimelineViewModel(
        path: '/unused',
        session: _Preview(),
        waveColor: '123456',
      );
    },
  );
}

class _Preview implements MediaPreviewSession {
  PreviewMediaInfo information = const PreviewMediaInfo(
    Duration(seconds: 10),
    videoIndex: 0,
    audioIndex: 1,
  );
  final positionEvents = StreamController<Duration>.broadcast();
  final completeEvents = StreamController<void>.broadcast();
  Completer<void>? inspectGate;
  Completer<void>? frameGate;
  Completer<void>? playGate;
  final frames = <int>[];
  final windows = <(int, int)>[];
  int activeFrames = 0;
  int maximumActiveFrames = 0;
  int revision = 0;
  bool closed = false;
  @override
  Stream<Duration> get positions => positionEvents.stream;
  @override
  Stream<void> get completed => completeEvents.stream;
  @override
  Duration get audioEnd => const Duration(seconds: 10);
  @override
  Future<PreviewMediaInfo> inspect(String path) async {
    await inspectGate?.future;
    return information;
  }

  @override
  Future<String?> frame(String path, Duration position) async {
    activeFrames++;
    if (activeFrames > maximumActiveFrames) maximumActiveFrames = activeFrames;
    frames.add(position.inMilliseconds);
    await frameGate?.future;
    activeFrames--;
    return 'frame-${position.inMilliseconds}.png';
  }

  @override
  Future<String?> waveform(
    String path,
    Duration start,
    Duration length,
    String color,
  ) async {
    windows.add((start.inMilliseconds, length.inMilliseconds));
    return 'wave.png';
  }

  @override
  Future<bool> play(String path, Duration start, Duration end) async {
    final current = ++revision;
    await playGate?.future;
    return !closed && current == revision;
  }

  @override
  Future<void> pause() async => revision++;
  @override
  Future<void> close() async {
    closed = true;
    revision++;
    await positionEvents.close();
    await completeEvents.close();
  }
}
