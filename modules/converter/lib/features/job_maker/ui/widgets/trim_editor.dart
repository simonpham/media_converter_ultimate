import 'dart:async';

import 'package:converter/converter.dart';
import 'package:flutter/material.dart';
import 'package:platform_utils/platform_utils.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

class const TrimEditor({
  super.key,
  required final String path,
  final ConversionTrim? initial,
}) extends StatefulWidget {
  @override
  State<TrimEditor> createState() => _TrimEditorState();
}

class _TrimEditorState extends State<TrimEditor> with WidgetsBindingObserver {
  final TextEditingController _startController = .new();
  final TextEditingController _endController = .new();
  final ScrollController _scrollController = .new();
  final FocusNode _startFocus = .new();
  final FocusNode _endFocus = .new();
  late final FileTrimViewModel _model;
  TrimTimelineViewModel? _timeline;
  late final Future<void> _fileReady;
  (int, int)? _lastBounds;
  bool _syncing = false;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _model = FileTrimViewModel(
      path: widget.path,
      initial: widget.initial,
      session: injector<MediaPreviewSession>(),
    );
    WidgetsBinding.instance.addObserver(this);
    _fileReady = _model.initialize();
    _model.addListener(_fieldsChanged);
    _startFocus.addListener(_focusChanged);
    _endFocus.addListener(_focusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_timeline != null) return;
    final color = this.context.theme.colorScheme.primary.toARGB32() & 0xffffff;
    _timeline = TrimTimelineViewModel(
      path: widget.path,
      initial: widget.initial,
      session: _model.session,
      waveColor: color.toRadixString(16).padLeft(6, '0'),
    )..addListener(_timelineChanged);
    unawaited(_initializeTimeline());
  }

  Future<void> _initializeTimeline() async {
    await _fileReady;
    if (!mounted || _model.failed) return;
    await _timeline!.initialize(information: _model.info);
    if (mounted) _fieldsChanged();
  }

  void _focusChanged() {
    final timeline = _timeline;
    if (timeline == null || timeline.loading || timeline.failed) return;
    if (_startFocus.hasFocus) timeline.selectTarget(.start);
    if (_endFocus.hasFocus) timeline.selectTarget(.end);
  }

  void _fieldsChanged() {
    final timeline = _timeline;
    if (_syncing || timeline == null || timeline.loading || !_model.canApply) {
      return;
    }
    final range = _model.range;
    final start = range?.start.inMilliseconds ?? 0;
    final end = range?.end?.inMilliseconds ?? timeline.duration;
    if ((start, end) == (timeline.start, timeline.end)) return;
    final target = start != timeline.start ? TrimTarget.start : TrimTarget.end;
    _syncing = true;
    _lastBounds = (start, end);
    timeline.setRange(start, end);
    timeline.adjustBoundary(target, target == .start ? start : end);
    _syncing = false;
  }

  void _timelineChanged() {
    final timeline = _timeline!;
    if (_syncing || timeline.loading || timeline.failed) return;
    final bounds = (timeline.start, timeline.end);
    if (_lastBounds == bounds) return;
    final hadBounds = _lastBounds != null;
    _lastBounds = bounds;
    if (!hadBounds) return;
    _syncing = true;
    _model.setRange(timeline.result);
    _syncing = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final timeline = _timeline;
    if (state != .resumed && timeline != null) {
      unawaited(timeline.pause());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timeline?.removeListener(_timelineChanged);
    _timeline?.dispose();
    _model.removeListener(_fieldsChanged);
    _model.dispose();
    _startController.dispose();
    _endController.dispose();
    _scrollController.dispose();
    _startFocus.dispose();
    _endFocus.dispose();
    super.dispose();
  }

  void _sync(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = .new(
      text: value,
      selection: .collapsed(offset: value.length),
    );
  }

  Widget _rangeControls(BuildContext context, FileTrimViewModel model) =>
      LayoutBuilder(
        builder: (context, constraints) {
          final start = InputText(
            key: const ValueKey('trim-start'),
            focusNode: _startFocus,
            controller: _startController,
            label: context.l10n.trimStart,
            hintText: MediaTimestamp.display(Duration.zero),
            inputPadding: .all(Spacing.d12),
            textStyle: context.theme.textTheme.bodyMedium,
            errorText: model.startFailure?.localized(context),
            onChanged: model.setStartText,
            textInputAction: .next,
            onSubmitted: (_) => _endFocus.requestFocus(),
          );
          final end = InputText(
            key: const ValueKey('trim-end'),
            focusNode: _endFocus,
            controller: _endController,
            label: context.l10n.trimEnd,
            hintText: model.duration == null
                ? context.l10n.trimEndOfFile
                : MediaTimestamp.display(model.duration!),
            inputPadding: .all(Spacing.d12),
            textStyle: context.theme.textTheme.bodyMedium,
            errorText: (model.endFailure ?? model.rangeFailure)?.localized(
              context,
            ),
            onChanged: model.setEndText,
            textInputAction: .done,
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
          );
          final scale =
              MediaQuery.textScalerOf(context).scale(Spacing.d12) / Spacing.d12;
          return constraints.maxWidth < Spacing.d96 * 3 * scale
              ? Column(
                  crossAxisAlignment: .stretch,
                  children: [start, Spacing.v12, end],
                )
              : Row(
                  crossAxisAlignment: .start,
                  children: [
                    Expanded(child: start),
                    Spacing.h12,
                    Expanded(child: end),
                  ],
                );
        },
      );

  @override
  Widget build(
    BuildContext context,
  ) => MultiProvider(
    providers: [
      ChangeNotifierProvider<FileTrimViewModel>.value(value: _model),
      ChangeNotifierProvider<TrimTimelineViewModel>.value(value: _timeline!),
    ],
    child: Consumer<FileTrimViewModel>(
      builder: (context, model, _) {
        _sync(_startController, model.startText);
        _sync(_endController, model.endText);
        return Scaffold(
          appBar: AppBar(title: Text(context.l10n.trimMediaTitle)),
          body: Column(
            children: [
              Expanded(
                child: AbsorbPointer(
                  absorbing: _applying,
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: .all(Spacing.d16),
                      child: Column(
                        crossAxisAlignment: .start,
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final name = Text(
                                File(widget.path).fileName,
                                style: context.theme.textTheme.titleSmall,
                                maxLines: 2,
                                overflow: .ellipsis,
                              );
                              final reset = Button(
                                variant: .ghost,
                                label: context.l10n.trimFullFile,
                                titleExpand: .shrink,
                                mainAxisSize: .min,
                                onPressed: () {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  model.reset();
                                  _timeline?.fitTimeline();
                                },
                              );
                              final scale =
                                  MediaQuery.textScalerOf(context)
                                      .scale(Spacing.d12) /
                                  Spacing.d12;
                              return constraints.maxWidth <
                                      Spacing.d96 * 3 * scale
                                  ? Column(
                                      crossAxisAlignment: .start,
                                      children: [name, Spacing.v8, reset],
                                    )
                                  : Row(
                                      children: [
                                        Expanded(child: name),
                                        Spacing.h8,
                                        reset,
                                      ],
                                    );
                            },
                          ),
                          Spacing.v8,
                          if (model.loading) const CircularProgressIndicator(),
                          if (model.failed)
                            Text(context.l10n.trimPreviewUnavailable),
                          if (model.duration case final duration?)
                            Text(
                              context.l10n.trimFileDuration(
                                MediaTimestamp.display(duration),
                              ),
                            ),
                          if (!model.loading && !model.failed) ...[
                            Spacing.v16,
                            TrimTimelinePanel(
                              rangeControls: _rangeControls(context, model),
                            ),
                          ] else ...[
                            Spacing.v16,
                            _rangeControls(context, model),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: .all(Spacing.d16),
                  child: Button(
                    key: const ValueKey('file-trim-apply'),
                    variant: .primary,
                    label: context.l10n.trimApplyRange,
                    titleExpand: .shrink,
                    enable: model.canApply && !_applying,
                    onPressed: () async {
                      if (_applying) return;
                      FocusManager.instance.primaryFocus?.unfocus();
                      final result = model.result;
                      setState(() => _applying = true);
                      await _timeline?.pause();
                      if (context.mounted) context.navigator.pop(result);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
