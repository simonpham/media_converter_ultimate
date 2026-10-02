import 'dart:async';
import 'dart:io';

import 'package:converter/converter.dart';
import 'package:flutter/material.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

/// Keeps the track's geometry stable while decoding and revealing its waveform.
class const TrimWaveformPreview({
  super.key,
  required final String? path,
  required final bool loading,
}) extends StatefulWidget {
  @override
  State<TrimWaveformPreview> createState() => _TrimWaveformPreviewState();
}

class _TrimWaveformPreviewState extends State<TrimWaveformPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  String? _requestedPath;
  String? _readyPath;
  String? _failedPath;
  int _revision = 0;

  bool get _preparing =>
      widget.loading ||
      (widget.path != null &&
          widget.path != _readyPath &&
          widget.path != _failedPath);

  void _syncMotion() {
    if (_preparing && !MediaQuery.disableAnimationsOf(context)) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prepareImage();
    _syncMotion();
  }

  @override
  void didUpdateWidget(TrimWaveformPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    _prepareImage();
    _syncMotion();
  }

  void _prepareImage() {
    final path = widget.path;
    if (path == _requestedPath) return;
    _requestedPath = path;
    _readyPath = null;
    _failedPath = null;
    final revision = ++_revision;
    if (path != null) unawaited(_decode(path, revision));
  }

  Future<void> _decode(String path, int revision) async {
    var failed = false;
    await precacheImage(
      FileImage(File(path)),
      context,
      onError: (_, _) => failed = true,
    );
    if (!mounted || revision != _revision) return;
    setState(() {
      _readyPath = failed ? null : path;
      _failedPath = failed ? path : null;
    });
    _syncMotion();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 240),
    switchInCurve: Curves.easeOut,
    switchOutCurve: Curves.easeIn,
    child: _readyPath != null
        ? SizedBox.expand(
            key: ValueKey(_readyPath),
            child: ImageView(_readyPath!, fit: .fill),
          )
        : _preparing
        ? Semantics(
            key: const ValueKey('trim-waveform-loading'),
            label: context.l10n.trimPreparingWaveform,
            liveRegion: true,
            child: ExcludeSemantics(
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (_, child) => Opacity(
                  opacity: 0.4 + _pulse.value * 0.35,
                  child: child,
                ),
                child: SizedBox.expand(
                  child: CustomPaint(
                    painter: _WaveformPlaceholderPainter(
                      context.theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
            ),
          )
        : const SizedBox.expand(),
  );
}

/// Decorative loading bars, separate from the measured waveform image.
class _WaveformPlaceholderPainter(final Color color) extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = Spacing.d2
      ..strokeCap = .round;
    final center = size.height / 2;
    const heights = [0.25, 0.45, 0.65, 0.45];
    for (
      var x = Spacing.d4, index = 0;
      x < size.width;
      x += Spacing.d8, index++
    ) {
      final extent = center * heights[index % heights.length];
      canvas.drawLine(
        Offset(x, center - extent),
        Offset(x, center + extent),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPlaceholderPainter oldDelegate) =>
      oldDelegate.color != color;
}
