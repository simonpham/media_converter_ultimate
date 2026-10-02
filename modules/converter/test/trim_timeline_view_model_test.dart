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

  test(
    'moving a handle leaves the opposing boundary intact and nudges its target',
    () async {
      await model.initialize();
      model.setRange(2000, 6000);
      model.adjustBoundary(.start, 9000);
      expect((model.start, model.end), (5999, 6000));
      model.adjustBoundary(.end, 0);
      expect((model.start, model.end), (5999, 6000));
      model.setRange(2000, 6000);
      model.selectTarget(.end);
      model.nudge(100);
      expect((model.start, model.end), (2000, 6100));
      model.moveRange(9000);
      expect((model.start, model.end), (5900, 10000));
      model.moveRange(-20000);
      expect((model.start, model.end), (0, 4100));
    },
  );

  test(
    'long media can select its far end without a range-length limit',
    () async {
      preview.information = const PreviewMediaInfo(
        Duration(hours: 2),
        videoIndex: 0,
      );
      await model.initialize();
      expect(model.isOverview, isTrue);
      expect((model.windowStart, model.windowEnd), (0, model.duration));
      model.selectTarget(.end);
      model.zoom(true);
      expect(model.windowEnd, model.duration);
      expect(model.start, 0);
      expect(model.end, 7200000);
      model.panWindow(false);
      expect(model.windowEnd, model.duration - 1800000);
      expect((model.start, model.end), (0, 7200000));
    },
  );

  test('zoomed waveform and cursor use the same bounded time window', () async {
    preview.information = const PreviewMediaInfo(
      Duration(minutes: 2),
      audioIndex: 1,
    );
    await model.initialize();
    expect(model.isOverview, isTrue);
    expect(model.needsWaveformZoom, isTrue);
    expect(preview.windows, isEmpty);
    model.zoom(true);
    model.zoom(true);
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
    expect(model.windowLength, 60000);
    expect(model.waveform, isNull);
    model.fitTimeline();
    expect(model.windowLength, 120000);
    expect(model.windowStart, 0);
  });

  test(
    'zoom spans the full file and preserves exact selected bounds',
    () async {
      preview.information = const PreviewMediaInfo(
        Duration(hours: 2),
        videoIndex: 0,
      );
      await model.initialize();
      model.setRange(850, 7185850);
      for (var i = 0; i < 25; i++) {
        model.zoom(true);
      }
      expect(model.windowLength, 100);
      expect(model.canZoomIn, isFalse);
      model.fitTimeline();
      expect(model.isOverview, isTrue);
      expect((model.windowStart, model.windowEnd), (0, 7200000));
      expect((model.start, model.end), (850, 7185850));
    },
  );

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
    'thumbnail requests keep only the latest viewport and reuse its image',
    () async {
      preview.information = const PreviewMediaInfo(
        Duration(minutes: 2),
        videoIndex: 0,
      );
      preview.stripGate = Completer<void>();
      await model.initialize();
      model.seek(60000);
      model.zoom(true);
      expect(preview.strips, [(0, 120000)]);
      expect(model.thumbnails, isNull);
      preview.stripGate!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(preview.strips, [(0, 120000), (30000, 60000)]);
      expect(model.thumbnails, 'strip-30000-60000.png');
      model.nudge(100);
      await Future<void>.delayed(Duration.zero);
      expect(preview.strips.length, 2);
      model.panWindow(true);
      expect(model.thumbnails, isNull);
      await Future<void>.delayed(Duration.zero);
      expect(model.thumbnails, 'strip-60000-60000.png');
    },
  );

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
  Completer<void>? stripGate;
  final strips = <(int, int)>[];
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
  Future<String?> thumbnails(
    String path,
    Duration start,
    Duration length,
  ) async {
    strips.add((start.inMilliseconds, length.inMilliseconds));
    await stripGate?.future;
    return 'strip-${start.inMilliseconds}-${length.inMilliseconds}.png';
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
