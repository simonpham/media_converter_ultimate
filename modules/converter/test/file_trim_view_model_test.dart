import 'dart:async';

import 'package:converter/converter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_utils/platform_utils.dart';

void main() {
  test(
    'draft rejects invalid timestamps and ranges outside its own duration',
    () async {
      final session = _Session();
      final model = FileTrimViewModel(path: '/short.wav', session: session);
      addTearDown(model.dispose);
      expect(model.canApply, isFalse);
      await model.initialize();
      expect(model.canApply, isTrue);
      model.setStartText('bad');
      expect(model.startFailure, isA<InvalidTrimTimestampFailure>());
      expect(model.canApply, isFalse);
      model.setStartText('0:01.125');
      model.setEndText('0:00.5');
      expect(model.rangeFailure, isA<InvalidTrimRangeFailure>());
      model.setEndText('0:05.001');
      expect(model.rangeFailure, isA<InvalidTrimBoundsFailure>());
      model.setEndText('0:03.5');
      expect(model.result.trim!.arguments, ['-ss', '1.125', '-t', '2.375']);
      model.setStartText('0:05');
      model.setEndText('');
      expect(model.rangeFailure, isA<InvalidTrimBoundsFailure>());
    },
  );

  test(
    'existing range remains precise and full-file Apply has a result',
    () async {
      final model = FileTrimViewModel(
        path: '/song.wav',
        session: _Session(),
        initial: const ConversionTrim(
          start: Duration(milliseconds: 750),
          end: Duration(milliseconds: 1750),
        ),
      );
      addTearDown(model.dispose);
      await model.initialize();
      expect(model.startText, '00:00.750');
      expect(model.endText, '00:01.750');
      model.setRange(
        const ConversionTrim(
          start: Duration(milliseconds: 850),
          end: Duration(milliseconds: 1850),
        ),
      );
      expect(model.result.trim!.arguments, ['-ss', '0.850', '-t', '1.000']);
      model.setEndText('0:05');
      expect(model.result.trim!.end, isNull);
      model.reset();
      expect(model.result.trim, isNull);
      expect(model.result.duration, const Duration(seconds: 5));
    },
  );

  test(
    'unreadable source disables Apply without modifying the initial range',
    () async {
      final model = FileTrimViewModel(
        path: '/gone.wav',
        session: _Session(fail: true),
      );
      addTearDown(model.dispose);
      await model.initialize();
      expect(model.failed, isTrue);
      expect(model.canApply, isFalse);
      expect(() => model.result, throwsStateError);
    },
  );

  test(
    'closing during probe suppresses late notifications and closes its session',
    () async {
      final gate = Completer<PreviewMediaInfo>();
      final session = _Session(gate: gate);
      final model = FileTrimViewModel(path: '/slow.wav', session: session);
      var notifications = 0;
      model.addListener(() => notifications++);
      final loading = model.initialize();
      model.dispose();
      gate.complete(const PreviewMediaInfo(Duration(seconds: 5)));
      await loading;
      expect(notifications, 0);
      expect(session.closed, isTrue);
    },
  );
}

class _Session({
  final bool fail = false,
  final Completer<PreviewMediaInfo>? gate,
}) implements MediaPreviewSession {
  bool closed = false;
  @override
  Future<PreviewMediaInfo> inspect(String path) async {
    if (fail) throw StateError('missing source');
    return gate == null
        ? const PreviewMediaInfo(Duration(seconds: 5))
        : await gate!.future;
  }

  @override
  Future<void> close() async {
    closed = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
