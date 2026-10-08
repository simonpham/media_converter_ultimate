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

  @override
  Widget build(
    BuildContext context,
  ) => ChangeNotifierProvider<TrimTimelineViewModel>.value(
    value: _model!,
    child: Consumer<TrimTimelineViewModel>(
      builder: (context, model, _) => Scaffold(
        appBar: AppBar(title: Text(context.l10n.trimPreviewTitle)),
        body: AdaptiveContent(
          child: Column(
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
                          const TrimTimelinePanel(),
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
    ),
  );
}
