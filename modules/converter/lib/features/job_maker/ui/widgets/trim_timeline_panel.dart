import 'dart:async';

import 'package:converter/converter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:icons/icons.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

/// The main trim controls stay visible; precision helpers expand on demand.
class const TrimTimelinePanel({super.key, final Widget? rangeControls})
    extends StatefulWidget {
  @override
  State<TrimTimelinePanel> createState() => _TrimTimelinePanelState();
}

class _TrimTimelinePanelState extends State<TrimTimelinePanel> {
  bool _fineAdjustment = false;

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
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: Spacing.d96 * 2),
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
            ),
            Spacing.v4,
            Text(
              context.l10n.trimFramePreview,
              style: context.theme.textTheme.bodySmall,
            ),
            Spacing.v12,
          ],
          Text(
            context.l10n.trimHandlesHint,
            style: context.theme.textTheme.bodySmall,
          ),
          Spacing.v4,
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
          widget.rangeControls ??
              Wrap(
                spacing: Spacing.d8,
                runSpacing: Spacing.d8,
                children: [
                  for (final target in [TrimTarget.start, TrimTarget.end])
                    _target(context, model, target, showTime: true),
                ],
              ),
          Spacing.v12,
          Wrap(
            spacing: Spacing.d8,
            runSpacing: Spacing.d8,
            alignment: .spaceBetween,
            crossAxisAlignment: .center,
            children: [
              if (model.info?.audioIndex != null)
                Button(
                  variant: .secondary,
                  mainAxisSize: .min,
                  titleExpand: .shrink,
                  padding: .symmetric(
                    horizontal: Spacing.d12,
                    vertical: Spacing.d8,
                  ),
                  enable: !model.preparingAudio,
                  label: model.preparingAudio
                      ? context.l10n.trimPreparingAudio
                      : model.playing
                      ? context.l10n.trimPauseAudio
                      : context.l10n.trimPlayAudio,
                  onPressed: () => _interact(
                    () =>
                        unawaited(model.playing ? model.pause() : model.play()),
                  ),
                ),
              Button(
                key: const ValueKey('trim-target-cursor'),
                titleExpand: .shrink,
                variant: .ghost,
                mainAxisSize: .min,
                padding: .symmetric(
                  horizontal: Spacing.d8,
                  vertical: Spacing.d8,
                ),
                tooltip: context.l10n.trimCursor,
                child: Text(
                  _time(model.position),
                  style: context.theme.textTheme.bodyMedium,
                ),
                onPressed: () => _interact(() => model.selectTarget(.cursor)),
              ),
            ],
          ),
          Spacing.v8,
          Wrap(
            spacing: Spacing.d8,
            runSpacing: Spacing.d8,
            crossAxisAlignment: .center,
            children: [
              Button(
                variant: .ghost,
                mainAxisSize: .min,
                padding: .all(Spacing.d12),
                tooltip: context.l10n.trimZoomOut,
                enable: !model.isOverview,
                child: SizedBox(
                  width: Spacing.d24,
                  child: Center(
                    child: Text('−', style: context.theme.textTheme.titleLarge),
                  ),
                ),
                onPressed: () => _interact(() => model.zoom(false)),
              ),
              _icon(
                context,
                context.l10n.trimZoomIn,
                Assets.add01,
                () => model.zoom(true),
                enabled: model.canZoomIn,
              ),
              Button(
                key: const ValueKey('trim-overview'),
                variant: .ghost,
                mainAxisSize: .min,
                titleExpand: .shrink,
                padding: .symmetric(
                  horizontal: Spacing.d12,
                  vertical: Spacing.d8,
                ),
                label: context.l10n.trimOverview,
                enable: !model.isOverview,
                onPressed: () => _interact(model.fitTimeline),
              ),
              Semantics(
                expanded: _fineAdjustment,
                child: Button(
                  key: const ValueKey('trim-fine-toggle'),
                  variant: .ghost,
                  mainAxisSize: .min,
                  titleExpand: .shrink,
                  padding: .symmetric(
                    horizontal: Spacing.d12,
                    vertical: Spacing.d8,
                  ),
                  child: Text(context.l10n.trimFineAdjustment),
                  trailingIcon: RotatedBox(
                    quarterTurns: _fineAdjustment ? 3 : 1,
                    child: ImageView(
                      Assets.arrowRight01Round,
                      size: Spacing.d16,
                      color: context.theme.colorScheme.primary,
                    ),
                  ),
                  onPressed: () => _interact(
                    () => setState(() => _fineAdjustment = !_fineAdjustment),
                  ),
                ),
              ),
            ],
          ),
          if (_fineAdjustment) ...[
            Spacing.v12,
            RoundCard(
              padding: .all(Spacing.d12),
              child: Column(
                crossAxisAlignment: .stretch,
                children: [
                  Wrap(
                    spacing: Spacing.d8,
                    runSpacing: Spacing.d8,
                    children: [
                      for (final target in TrimTarget.values)
                        _target(context, model, target),
                    ],
                  ),
                  Spacing.v8,
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
                            vertical: Spacing.d12,
                          ),
                          label: context.l10n.trimSeekStep(
                            '${milliseconds > 0 ? '+' : '−'}${milliseconds.abs() / 1000}',
                          ),
                          onPressed: () =>
                              _interact(() => model.nudge(milliseconds)),
                        ),
                    ],
                  ),
                  if (!model.isOverview) ...[
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
                      ],
                    ),
                  ],
                  Spacing.v8,
                  Text(
                    context.l10n.trimMediaDescription,
                    style: context.theme.textTheme.bodySmall,
                  ),
                  Spacing.v8,
                  Text(
                    context.l10n.trimAccuracyHint,
                    style: context.theme.textTheme.bodySmall,
                  ),
                  if (model.info?.audioIndex != null) ...[
                    Spacing.v8,
                    Text(
                      context.l10n.trimAudioPreviewLimit,
                      style: context.theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (model.imageFailed) Text(context.l10n.trimPreviewUnavailable),
        ],
      );
    },
  );

  Widget _target(
    BuildContext context,
    TrimTimelineViewModel model,
    TrimTarget target, {
    bool showTime = false,
  }) {
    final label = switch (target) {
      .start => context.l10n.trimStart,
      .cursor => context.l10n.trimCursor,
      .end => context.l10n.trimEnd,
    };
    return Semantics(
      selected: model.target == target,
      child: Button(
        key: ValueKey('trim-fine-target-${target.name}'),
        variant: model.target == target ? .secondary : .ghost,
        titleExpand: .shrink,
        mainAxisSize: .min,
        padding: .symmetric(horizontal: Spacing.d12, vertical: Spacing.d8),
        label: showTime
            ? '$label ${_time(target == .start ? model.start : model.end)}'
            : label,
        onPressed: () => _interact(() => model.selectTarget(target)),
      ),
    );
  }

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
    padding: .all(Spacing.d12),
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
            height: Spacing.d64,
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
                        _ when model.preparingWaveform => Center(
                          child: Semantics(
                            label: context.l10n.trimPreparingWaveform,
                            child: SizedBox(
                              width: Spacing.d24,
                              height: Spacing.d24,
                              child: CircularProgressIndicator(
                                strokeWidth: Spacing.d2,
                              ),
                            ),
                          ),
                        ),
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
    for (var index = 1; index < 4; index++) {
      final x = lane.left + lane.width * index / 4;
      canvas.drawLine(
        Offset(x, lane.top),
        Offset(x, lane.bottom),
        Paint()
          ..color = colors.outlineVariant.withValues(alpha: 0.5)
          ..strokeWidth = Spacing.d1,
      );
    }
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
        Paint()
          ..color = colors.primary
          ..style = .stroke
          ..strokeWidth = Spacing.d2,
      );
      canvas.drawLine(
        Offset(x, lane.center.dy - Spacing.d12),
        Offset(x, lane.center.dy + Spacing.d12),
        Paint()
          ..color = colors.primary
          ..strokeWidth = Spacing.d1,
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
