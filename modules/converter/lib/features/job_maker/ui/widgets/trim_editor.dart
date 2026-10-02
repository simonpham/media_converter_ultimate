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

class _TrimEditorState extends State<TrimEditor> {
  final TextEditingController _startController = .new();
  final TextEditingController _endController = .new();
  final ScrollController _scrollController = .new();
  late final FileTrimViewModel _model;

  @override
  void initState() {
    super.initState();
    _model = FileTrimViewModel(
      path: widget.path,
      initial: widget.initial,
      session: injector<MediaPreviewSession>(),
    );
    unawaited(_model.initialize());
  }

  @override
  void dispose() {
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
  ) => ChangeNotifierProvider<FileTrimViewModel>.value(
    value: _model,
    child: Consumer<FileTrimViewModel>(
      builder: (context, model, _) {
        _sync(_startController, model.startText);
        _sync(_endController, model.endText);
        return Scaffold(
          appBar: AppBar(title: Text(context.l10n.trimMediaTitle)),
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
                          File(widget.path).fileName,
                          style: context.theme.textTheme.titleMedium,
                        ),
                        Spacing.v8,
                        Text(context.l10n.trimMediaDescription),
                        Spacing.v12,
                        if (model.loading) const CircularProgressIndicator(),
                        if (model.failed)
                          Text(context.l10n.trimPreviewUnavailable),
                        if (model.duration case final duration?)
                          Text(
                            context.l10n.trimFileDuration(
                              MediaTimestamp.display(duration),
                            ),
                          ),
                        Spacing.v16,
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
                          onSubmitted: (_) => FocusScope.of(context).unfocus(),
                        ),
                        Spacing.v16,
                        Wrap(
                          spacing: Spacing.d8,
                          runSpacing: Spacing.d8,
                          children: [
                            Button(
                              variant: .secondary,
                              label: context.l10n.trimPreviewTitle,
                              titleExpand: .shrink,
                              enable: model.canApply,
                              onPressed: () =>
                                  unawaited(_openTimeline(context)),
                            ),
                            Button(
                              variant: .ghost,
                              label: context.l10n.trimFullFile,
                              titleExpand: .shrink,
                              onPressed: model.reset,
                            ),
                          ],
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
              SafeArea(
                top: false,
                child: Padding(
                  padding: .all(Spacing.d16),
                  child: Button(
                    key: const ValueKey('file-trim-apply'),
                    variant: .primary,
                    label: context.l10n.trimApplyRange,
                    titleExpand: .shrink,
                    enable: model.canApply,
                    onPressed: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      context.navigator.pop(model.result);
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

  Future<void> _openTimeline(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final range = await context.navigator.push<ConversionTrim>(
      MaterialPageRoute(
        builder: (context) =>
            TrimTimeline(path: widget.path, initial: _model.range),
      ),
    );
    if (context.mounted && range != null) _model.setRange(range);
  }
}
