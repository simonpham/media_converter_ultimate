import 'dart:async';

import 'package:converter/converter.dart';
import 'package:flutter/material.dart';
import 'package:platform_utils/platform_utils.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

class const TrimEditor({super.key}) extends StatefulWidget {
  @override
  State<TrimEditor> createState() => _TrimEditorState();
}

class _TrimEditorState extends State<TrimEditor> {
  final TextEditingController _startController = .new();
  final TextEditingController _endController = .new();

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
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
  Widget build(BuildContext context) => Consumer<JobMakerViewModel>(
    builder: (context, model, _) {
      _sync(_startController, model.trimStartText);
      _sync(_endController, model.trimEndText);
      return RoundCard(
        margin: .symmetric(horizontal: Spacing.d16),
        padding: .symmetric(vertical: Spacing.d12),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            CheckBoxListTile(
              alignment: .left,
              title: context.l10n.trimMediaTitle,
              subtitle: context.l10n.trimMediaDescription,
              value: model.trimEnabled,
              onChanged: model.setTrimEnabled,
            ),
            if (model.trimEnabled)
              Padding(
                padding: .symmetric(horizontal: Spacing.d16),
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    Spacing.v8,
                    InputText(
                      key: const ValueKey('trim-start'),
                      controller: _startController,
                      label: context.l10n.trimStart,
                      hintText: context.l10n.trimTimeHint,
                      errorText: model.trimStartFailure?.localized(context),
                      onChanged: model.setTrimStartText,
                      textInputAction: .next,
                      onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                    ),
                    Spacing.v12,
                    InputText(
                      key: const ValueKey('trim-end'),
                      controller: _endController,
                      label: context.l10n.trimEnd,
                      hintText: context.l10n.trimEndOfFile,
                      errorText:
                          (model.trimEndFailure ?? model.trimRangeFailure)
                              ?.localized(context),
                      onChanged: model.setTrimEndText,
                      textInputAction: .done,
                      onSubmitted: (_) => FocusScope.of(context).unfocus(),
                    ),
                    Spacing.v12,
                    Button(
                      variant: .secondary,
                      label: context.l10n.trimPreviewTitle,
                      titleExpand: .shrink,
                      enable: model.selectedFiles.isNotEmpty,
                      onPressed: () => unawaited(_openTimeline(context, model)),
                    ),
                    Spacing.v12,
                    Text(
                      context.l10n.trimAccuracyHint,
                      style: context.theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );

  Future<void> _openTimeline(
    BuildContext context,
    JobMakerViewModel model,
  ) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final files = [...model.selectedFiles];
    if (files.isEmpty) return;
    final file = files.length == 1
        ? files.first
        : await RadioOptionsDialog.show<File>(
            context,
            title: context.l10n.preview,
            message: null,
            cancelText: context.l10n.cancel,
            confirmText: context.l10n.ok,
            initialValue: files.first,
            values: files,
            itemLabelBuilder: (file) => file.fileName,
          );
    if (!context.mounted || file == null) return;
    final range = await context.navigator.push<ConversionTrim>(
      MaterialPageRoute(
        builder: (context) =>
            TrimTimeline(path: file.path, initial: model.selectedTrim),
      ),
    );
    if (context.mounted && range != null) model.setTrimRange(range);
  }
}
