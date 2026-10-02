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
    super.dispose();
  }

  void _sync(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = .new(
      text: value,
      selection: .collapsed(offset: value.length),
    );
  }

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
                                style: context.theme.textTheme.titleMedium,
                              );
                              final reset = Button(
                                variant: .ghost,
                                label: context.l10n.trimFullFile,
                                titleExpand: .shrink,
                                mainAxisSize: .min,
                                onPressed: model.reset,
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
                            const TrimTimelinePanel(),
                          ],
                          Spacing.v16,
                          Text(context.l10n.trimMediaDescription),
                          Spacing.v12,
                          InputText(
                            key: const ValueKey('trim-start'),
                            controller: _startController,
                            label: context.l10n.trimStart,
                            hintText: context.l10n.trimTimeHint,
                            errorText: model.startFailure?.localized(context),
                            onChanged: model.setStartText,
                            textInputAction: .next,
                            onSubmitted: (_) =>
                                FocusScope.of(context).nextFocus(),
                          ),
                          Spacing.v12,
                          InputText(
                            key: const ValueKey('trim-end'),
                            controller: _endController,
                            label: context.l10n.trimEnd,
                            hintText: context.l10n.trimEndOfFile,
                            errorText: (model.endFailure ?? model.rangeFailure)
                                ?.localized(context),
                            onChanged: model.setEndText,
                            textInputAction: .done,
                            onSubmitted: (_) =>
                                FocusScope.of(context).unfocus(),
                          ),
                          Spacing.v12,
                          Text(
                            context.l10n.trimAccuracyHint,
                            style: context.theme.textTheme.bodySmall,
                          ),
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
