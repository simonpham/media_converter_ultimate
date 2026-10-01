import 'dart:async';

import 'package:converter/converter.dart';
import 'package:flutter/material.dart';
import 'package:platform_utils/platform_utils.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

class const TrimTimeline({
  super.key,
  required final String path,
  final ConversionTrim? initial,
}) extends StatefulWidget {
  @override
  State<TrimTimeline> createState() => _TrimTimelineState();
}

class _TrimTimelineState extends State<TrimTimeline>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = .new();
  TrimTimelineViewModel? _model;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_model != null) return;
    WidgetsBinding.instance.addObserver(this);
    final color = this.context.theme.colorScheme.primary.toARGB32() & 0xffffff;
    _model = TrimTimelineViewModel(
      path: widget.path,
      initial: widget.initial,
      session: injector<MediaPreviewSession>(),
      waveColor: color.toRadixString(16).padLeft(6, '0'),
    );
    unawaited(_model!.initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_model!.pause());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _model?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _time(int milliseconds) =>
      MediaTimestamp.display(Duration(milliseconds: milliseconds));

  @override
  Widget build(
    BuildContext context,
  ) => ChangeNotifierProvider<TrimTimelineViewModel>.value(
    value: _model!,
    child: Consumer<TrimTimelineViewModel>(
      builder: (context, model, _) => Scaffold(
        appBar: AppBar(title: Text(context.l10n.trimPreviewTitle)),
        body: Column(
          children: [
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: .all(Spacing.d16),
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Text(
                        basename(widget.path),
                        style: context.theme.textTheme.titleMedium,
                      ),
                      Spacing.v12,
                      Text(context.l10n.trimPreviewDescription),
                      Spacing.v16,
                      if (model.loading)
                        const Center(child: CircularProgressIndicator())
                      else if (model.failed) ...[
                        Text(context.l10n.trimPreviewUnavailable),
                      ] else ...[
                        if (model.info?.videoIndex != null) ...[
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: model.frame == null
                                ? Center(
                                    child: Text(context.l10n.trimFramePreview),
                                  )
                                : ImageView(model.frame!, fit: .contain),
                          ),
                          Spacing.v12,
                          Text(
                            context.l10n.trimFramePreview,
                            style: context.theme.textTheme.bodySmall,
                          ),
                          Spacing.v12,
                        ],
                        Text(
                          context.l10n.trimMediaTitle,
                          style: context.theme.textTheme.titleSmall,
                        ),
                        RangeSlider(
                          key: const ValueKey('trim-range-slider'),
                          min: 0,
                          max: model.duration.toDouble(),
                          values: RangeValues(
                            model.start.toDouble(),
                            model.end.toDouble(),
                          ),
                          labels: RangeLabels(
                            _time(model.start),
                            _time(model.end),
                          ),
                          onChanged: (values) => model.setRange(
                            values.start.round(),
                            values.end.round(),
                          ),
                        ),
                        Text(
                          '${context.l10n.trimStart}: ${_time(model.start)}',
                        ),
                        Text(
                          '${context.l10n.trimEnd}: ${model.end == model.duration ? context.l10n.trimEndOfFile : _time(model.end)}',
                        ),
                        Spacing.v16,
                        Text(
                          _time(model.position),
                          style: context.theme.textTheme.titleLarge,
                        ),
                        SizedBox(
                          height: Spacing.d96,
                          child: Stack(
                            alignment: .center,
                            children: [
                              if (model.waveform != null)
                                Positioned.fill(
                                  child: ImageView(model.waveform!, fit: .fill),
                                ),
                              Slider(
                                key: const ValueKey('trim-position-slider'),
                                min: model.windowStart.toDouble(),
                                max: model.windowEnd.toDouble(),
                                value: model.position
                                    .clamp(model.windowStart, model.windowEnd)
                                    .toDouble(),
                                label: _time(model.position),
                                onChanged: (value) =>
                                    model.seek(value.round(), preview: false),
                                onChangeEnd: (value) =>
                                    model.seek(value.round()),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisAlignment: .spaceBetween,
                          children: [
                            Text(_time(model.windowStart)),
                            Text(_time(model.windowEnd)),
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
                                label: context.l10n.trimSeekStep(
                                  '${milliseconds > 0 ? '+' : '−'}${milliseconds.abs() / 1000}',
                                ),
                                onPressed: () => model.nudge(milliseconds),
                              ),
                            Button(
                              variant: .ghost,
                              titleExpand: .shrink,
                              mainAxisSize: .min,
                              label: context.l10n.trimZoomIn,
                              onPressed: () => model.zoom(true),
                            ),
                            Button(
                              variant: .ghost,
                              titleExpand: .shrink,
                              mainAxisSize: .min,
                              label: context.l10n.trimZoomOut,
                              onPressed: () => model.zoom(false),
                            ),
                          ],
                        ),
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
                              onPressed: model.setStartAtCursor,
                            ),
                            Button(
                              variant: .secondary,
                              titleExpand: .shrink,
                              mainAxisSize: .min,
                              label: context.l10n.trimSetEnd,
                              onPressed: model.setEndAtCursor,
                            ),
                          ],
                        ),
                        Spacing.v16,
                        if (model.info?.audioIndex != null) ...[
                          Button(
                            variant: .secondary,
                            enable: !model.preparingAudio,
                            label: model.preparingAudio
                                ? context.l10n.trimPreparingAudio
                                : model.playing
                                ? context.l10n.trimPauseAudio
                                : context.l10n.trimPlayAudio,
                            onPressed: () => unawaited(
                              model.playing ? model.pause() : model.play(),
                            ),
                          ),
                          Spacing.v8,
                          Text(
                            context.l10n.trimAudioPreviewLimit,
                            style: context.theme.textTheme.bodySmall,
                          ),
                        ],
                        if (model.imageFailed)
                          Text(context.l10n.trimPreviewUnavailable),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: .all(Spacing.d16),
              child: Button(
                variant: .primary,
                label: context.l10n.trimApplyRange,
                enable: !model.loading && !model.failed,
                onPressed: () async {
                  final result = model.result;
                  await model.pause();
                  if (context.mounted) context.navigator.pop(result);
                },
              ),
            ),
            const BottomSpacer(),
          ],
        ),
      ),
    ),
  );
}
