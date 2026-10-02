import 'dart:async';

import 'package:converter/converter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:icons/icons.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

/// One visual track connects range boundaries, the playhead and frame preview.
class const TrimTimelinePanel({super.key}) extends StatelessWidget {
  String _time(int value) =>
      MediaTimestamp.display(Duration(milliseconds: value));

  void _interact(VoidCallback action) {
    FocusManager.instance.primaryFocus?.unfocus();
    action();
  }

  @override
  Widget build(BuildContext context) => Consumer<TrimTimelineViewModel>(
    builder: (context, model, _) {
      if (model.loading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (model.failed) return Text(context.l10n.trimPreviewUnavailable);
      return Column(
        crossAxisAlignment: .stretch,
        children: [
          if (model.info?.videoIndex != null) ...[
            ClipRRect(
              borderRadius: Spacing.r12,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: ColoredBox(
                  color: context.theme.colorScheme.surfaceContainerHighest,
                  child: model.frame == null
                      ? Center(child: Text(context.l10n.trimFramePreview))
                      : ImageView(model.frame!, fit: .contain),
                ),
              ),
            ),
            Spacing.v8,
            Text(
              context.l10n.trimFramePreview,
              style: context.theme.textTheme.bodySmall,
            ),
            Spacing.v12,
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final scale =
                  MediaQuery.textScalerOf(context).scale(Spacing.d12) /
                  Spacing.d12;
              final columns =
                  ((constraints.maxWidth + Spacing.d8) /
                          (Spacing.d96 * scale + Spacing.d8))
                      .floor()
                      .clamp(1, 3);
              final width =
                  (constraints.maxWidth - Spacing.d8 * (columns - 1)) / columns;
              return Wrap(
                spacing: Spacing.d8,
                runSpacing: Spacing.d8,
                children: [
                  for (final target in TrimTarget.values)
                    SizedBox(
                      width: width,
                      child: Semantics(
                        button: true,
                        selected: model.target == target,
                        child: Tappable(
                          key: ValueKey('trim-target-${target.name}'),
                          onTap: () =>
                              _interact(() => model.selectTarget(target)),
                          child: RoundCard(
                            padding: .all(Spacing.d8),
                            color: model.target == target
                                ? context.theme.colorScheme.primary.withValues(
                                    alpha: 0.12,
                                  )
                                : context.theme.cardColor,
                            child: SizedBox(
                              width: double.infinity,
                              child: Column(
                                crossAxisAlignment: .start,
                                children: [
                                  Text(switch (target) {
                                    .start => context.l10n.trimStart,
                                    .cursor => context.l10n.trimCursor,
                                    .end => context.l10n.trimEnd,
                                  }, style: context.theme.textTheme.labelSmall),
                                  Spacing.v4,
                                  Text(
                                    _time(switch (target) {
                                      .start => model.start,
                                      .cursor => model.position,
                                      .end => model.end,
                                    }),
                                    style: context.theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          Spacing.v8,
          _TrimTrack(model: model),
          Row(
            mainAxisAlignment: .spaceBetween,
            children: [
              Text(
                _time(model.windowStart),
                style: context.theme.textTheme.labelSmall,
              ),
              Text(
                _time(model.windowEnd),
                style: context.theme.textTheme.labelSmall,
              ),
            ],
          ),
          Spacing.v12,
          Wrap(
            spacing: Spacing.d8,
            runSpacing: Spacing.d8,
            children: [
              for (final milliseconds in [-1000, -100, 100, 1000])
                Button(
                  variant: .ghost,
                  titleExpand: .shrink,
                  mainAxisSize: .min,
                  padding: .symmetric(
                    horizontal: Spacing.d12,
                    vertical: Spacing.d8,
                  ),
                  label: context.l10n.trimSeekStep(
                    '${milliseconds > 0 ? '+' : '−'}${milliseconds.abs() / 1000}',
                  ),
                  onPressed: () => _interact(() => model.nudge(milliseconds)),
                ),
            ],
          ),
          Spacing.v8,
          Row(
            children: [
              _icon(
                context,
                context.l10n.trimPreviousWindow,
                Assets.arrowRight01Round,
                () => model.panWindow(false),
                rotate: 2,
                enabled: model.windowStart > 0,
              ),
              Spacing.h8,
              _icon(
                context,
                context.l10n.trimNextWindow,
                Assets.arrowRight01Round,
                () => model.panWindow(true),
                enabled: model.windowEnd < model.duration,
              ),
              const Spacer(),
              Button(
                variant: .ghost,
                mainAxisSize: .min,
                padding: .all(Spacing.d8),
                tooltip: context.l10n.trimZoomOut,
                enable: model.windowLength < model.duration.clamp(1, 30000),
                child: SizedBox(
                  width: Spacing.d24,
                  child: Center(
                    child: Text('−', style: context.theme.textTheme.titleLarge),
                  ),
                ),
                onPressed: () => _interact(() => model.zoom(false)),
              ),
              Spacing.h8,
              _icon(
                context,
                context.l10n.trimZoomIn,
                Assets.add01,
                () => model.zoom(true),
                enabled: model.windowLength > 1,
              ),
            ],
          ),
          if (model.target == .cursor) ...[
            Spacing.v12,
            Wrap(
              spacing: Spacing.d8,
              runSpacing: Spacing.d8,
              children: [
                Button(
                  variant: .secondary,
                  titleExpand: .shrink,
                  mainAxisSize: .min,
                  label: context.l10n.trimSetStart,
                  onPressed: () => _interact(model.setStartAtCursor),
                ),
                Button(
                  variant: .secondary,
                  titleExpand: .shrink,
                  mainAxisSize: .min,
                  label: context.l10n.trimSetEnd,
                  onPressed: () => _interact(model.setEndAtCursor),
                ),
              ],
            ),
          ],
          if (model.info?.audioIndex != null) ...[
            Spacing.v12,
            Button(
              variant: .secondary,
              titleExpand: .shrink,
              enable: !model.preparingAudio,
              label: model.preparingAudio
                  ? context.l10n.trimPreparingAudio
                  : model.playing
                  ? context.l10n.trimPauseAudio
                  : context.l10n.trimPlayAudio,
              onPressed: () =>
                  unawaited(model.playing ? model.pause() : model.play()),
            ),
            Spacing.v8,
            Text(
              context.l10n.trimAudioPreviewLimit,
              style: context.theme.textTheme.bodySmall,
            ),
          ],
          if (model.imageFailed) Text(context.l10n.trimPreviewUnavailable),
        ],
      );
    },
  );

  Widget _icon(
    BuildContext context,
    String tooltip,
    String asset,
    VoidCallback onTap, {
    int rotate = 0,
    bool enabled = true,
  }) => Button(
    variant: .ghost,
    mainAxisSize: .min,
    padding: .all(Spacing.d8),
    tooltip: tooltip,
    enable: enabled,
    onPressed: () => _interact(onTap),
    child: RotatedBox(
      quarterTurns: rotate,
      child: ImageView(
        asset,
        size: Spacing.d24,
        color: context.theme.colorScheme.primary,
      ),
    ),
  );
}

enum _TrackDrag { start, end, range, cursor }

class const _TrimTrack({required final TrimTimelineViewModel model})
    extends StatefulWidget {
  @override
  State<_TrimTrack> createState() => _TrimTrackState();
}

class _TrimTrackState extends State<_TrimTrack> {
  _TrackDrag _drag = .cursor;
  double _down = 0;
  int _originalStart = 0;
  int _originalLength = 1;
  double _width = 1;
  double get _usable => (_width - Spacing.d48).clamp(1, double.infinity);
  double _x(int time) =>
      Spacing.d24 +
      (time - widget.model.windowStart) / widget.model.windowLength * _usable;
  int _time(double x) =>
      (widget.model.windowStart +
              (x - Spacing.d24).clamp(0, _usable) /
                  _usable *
                  widget.model.windowLength)
          .round();
  bool _visible(int time) =>
      time >= widget.model.windowStart && time <= widget.model.windowEnd;

  _TrackDrag _hit(double x) {
    final model = widget.model;
    final left = (x - _x(model.start)).abs();
    final right = (x - _x(model.end)).abs();
    if (_visible(model.start) &&
        left <= Spacing.d24 &&
        (!_visible(model.end) || left <= right)) {
      return .start;
    }
    if (_visible(model.end) && right <= Spacing.d24) return .end;
    if (x > _x(model.start) &&
        x < _x(model.end) &&
        model.end - model.start < model.duration) {
      return .range;
    }
    return .cursor;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _width = constraints.maxWidth;
      final model = widget.model;
      return Semantics(
        label: context.l10n.trimMediaTitle,
        child: GestureDetector(
          key: const ValueKey('trim-visual-track'),
          behavior: .opaque,
          dragStartBehavior: DragStartBehavior.down,
          onTapUp: (details) {
            FocusManager.instance.primaryFocus?.unfocus();
            final hit = _hit(details.localPosition.dx);
            if (hit == .start || hit == .end) {
              model.selectTarget(hit == .start ? .start : .end);
            } else {
              model.adjustBoundary(.cursor, _time(details.localPosition.dx));
            }
          },
          onHorizontalDragStart: (details) {
            FocusManager.instance.primaryFocus?.unfocus();
            _down = details.localPosition.dx;
            _drag = _hit(_down);
            _originalStart = model.start;
            _originalLength = model.end - model.start;
          },
          onHorizontalDragUpdate: (details) {
            final at = _time(details.localPosition.dx);
            switch (_drag) {
              case .start:
                model.adjustBoundary(.start, at, preview: false);
              case .end:
                model.adjustBoundary(.end, at, preview: false);
              case .range:
                final delta =
                    ((details.localPosition.dx - _down) /
                            _usable *
                            model.windowLength)
                        .round();
                final start = (_originalStart + delta).clamp(
                  0,
                  model.duration - _originalLength,
                );
                model.moveRange(start - model.start, preview: false);
              case .cursor:
                model.adjustBoundary(.cursor, at, preview: false);
            }
          },
          onHorizontalDragEnd: (_) => model.seek(model.position),
          onHorizontalDragCancel: () => model.seek(model.position),
          child: SizedBox(
            height: Spacing.d96,
            child: Stack(
              children: [
                Positioned(
                  left: Spacing.d24,
                  right: Spacing.d24,
                  top: Spacing.d8,
                  bottom: Spacing.d8,
                  child: ClipRRect(
                    borderRadius: Spacing.r8,
                    child: ColoredBox(
                      color: context.theme.colorScheme.surfaceContainerHighest,
                      child: switch (model.info?.videoIndex != null
                          ? model.thumbnails
                          : model.waveform) {
                        final String path => ImageView(path, fit: .fill),
                        _ => const SizedBox.expand(),
                      },
                    ),
                  ),
                ),
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: CustomPaint(
                      painter: _TrackPainter(
                        start: _x(model.start),
                        end: _x(model.end),
                        cursor: _x(model.position),
                        showStart: _visible(model.start),
                        showEnd: _visible(model.end),
                        showCursor: _visible(model.position),
                        colors: context.theme.colorScheme,
                      ),
                    ),
                  ),
                ),
                for (final target in [TrimTarget.start, TrimTarget.end])
                  if (_visible(target == .start ? model.start : model.end))
                    Positioned(
                      left:
                          _x(target == .start ? model.start : model.end) -
                          Spacing.d24,
                      top: 0,
                      bottom: 0,
                      width: Spacing.d48,
                      child: Semantics(
                        slider: true,
                        label: target == .start
                            ? context.l10n.trimStart
                            : context.l10n.trimEnd,
                        value: MediaTimestamp.display(
                          Duration(
                            milliseconds: target == .start
                                ? model.start
                                : model.end,
                          ),
                        ),
                        increasedValue: MediaTimestamp.display(
                          Duration(
                            milliseconds: target == .start
                                ? (model.start + 100).clamp(0, model.end - 1)
                                : (model.end + 100).clamp(
                                    model.start + 1,
                                    model.duration,
                                  ),
                          ),
                        ),
                        decreasedValue: MediaTimestamp.display(
                          Duration(
                            milliseconds: target == .start
                                ? (model.start - 100).clamp(0, model.end - 1)
                                : (model.end - 100).clamp(
                                    model.start + 1,
                                    model.duration,
                                  ),
                          ),
                        ),
                        onIncrease: () => model.adjustBoundary(
                          target,
                          (target == .start ? model.start : model.end) + 100,
                        ),
                        onDecrease: () => model.adjustBoundary(
                          target,
                          (target == .start ? model.start : model.end) - 100,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _TrackPainter({
  required final double start,
  required final double end,
  required final double cursor,
  required final bool showStart,
  required final bool showEnd,
  required final bool showCursor,
  required final ColorScheme colors,
}) extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final lane = Rect.fromLTRB(
      Spacing.d24,
      Spacing.d8,
      size.width - Spacing.d24,
      size.height - Spacing.d8,
    );
    final left = start.clamp(lane.left, lane.right);
    final right = end.clamp(lane.left, lane.right);
    final shade = Paint()..color = colors.surface.withValues(alpha: 0.72);
    canvas.drawRect(
      Rect.fromLTRB(lane.left, lane.top, left, lane.bottom),
      shade,
    );
    canvas.drawRect(
      Rect.fromLTRB(right, lane.top, lane.right, lane.bottom),
      shade,
    );
    final border = Paint()
      ..color = colors.primary
      ..style = .stroke
      ..strokeWidth = Spacing.d2;
    canvas.drawRect(Rect.fromLTRB(left, lane.top, right, lane.bottom), border);
    for (final x in [if (showStart) start, if (showEnd) end]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(x - Spacing.d8, lane.top, x + Spacing.d8, lane.bottom),
          Radius.circular(Spacing.d4),
        ),
        Paint()..color = colors.primary,
      );
      canvas.drawLine(
        Offset(x, lane.center.dy - Spacing.d12),
        Offset(x, lane.center.dy + Spacing.d12),
        Paint()
          ..color = colors.onPrimary
          ..strokeWidth = Spacing.d2,
      );
    }
    if (showCursor) {
      canvas.drawLine(
        Offset(cursor, lane.top),
        Offset(cursor, lane.bottom),
        Paint()
          ..color = colors.onSurface
          ..strokeWidth = Spacing.d2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrackPainter old) =>
      start != old.start ||
      end != old.end ||
      cursor != old.cursor ||
      showStart != old.showStart ||
      showEnd != old.showEnd ||
      showCursor != old.showCursor ||
      colors != old.colors;
}
