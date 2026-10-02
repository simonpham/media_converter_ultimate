import 'dart:async';

import 'package:converter/converter.dart';
import 'package:flutter/material.dart';
import 'package:icons/icons.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

extension JobLogViewerExt on ConvertJob {
  Future<void> openLogs(BuildContext context) async {
    if (logs.isEmpty) {
      return;
    }
    await context.navigator.push(
      MaterialPageRoute(
        builder: (context) => JobLogViewer(job: this),
      ),
    );
  }
}

class const JobLogViewer({
  super.key,
  required final ConvertJob job,
}) extends StatefulWidget {
  @override
  State<JobLogViewer> createState() => _JobLogViewerState();
}

class _JobLogViewerState extends State<JobLogViewer> {
  final _scrollController = ScrollController();
  final MenuController _menuController = .new();
  final TextEditingController _searchController = .new();
  late final JobLogViewModel _model = JobLogViewModel(widget.job)..initialize();

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<JobLogViewModel>.value(
      value: _model,
      child: Consumer<JobLogViewModel>(
        builder: (context, model, _) => Scaffold(
          appBar: AppBar(
            title: Text(widget.job.outputFileName),
            actions: [
              Directionality(
                textDirection: Directionality.of(context) == .ltr ? .rtl : .ltr,
                child: MenuAnchor(
                  controller: _menuController,
                  alignmentOffset: .new(0, Spacing.d4),
                  menuChildren: [
                    _logAction(
                      context,
                      context.l10n.copyFullLog,
                      enabled: model.logs.isNotEmpty,
                      onTap: () => unawaited(_copy(context)),
                    ),
                    _logAction(
                      context,
                      context.l10n.exportFullLog,
                      enabled: model.logs.isNotEmpty && !model.isExporting,
                      onTap: () => unawaited(_export(context)),
                    ),
                  ],
                  builder: (context, controller, _) => Button(
                    key: const ValueKey('log-actions'),
                    variant: .ghost,
                    borderWidth: 0,
                    width: Spacing.d48,
                    height: Spacing.d48,
                    padding: .all(Spacing.d12),
                    tooltip: MaterialLocalizations.of(context)
                        .moreButtonTooltip,
                    child: ImageView(
                      Assets.moreVertical,
                      size: Spacing.d24,
                      color: context.theme.colorScheme.onSurface,
                    ),
                    onPressed: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      if (controller.isOpen) {
                        controller.close();
                      } else {
                        controller.open();
                      }
                    },
                  ),
                ),
              ),
              Spacing.h8,
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: .all(Spacing.d16),
                child: InputText(
                  controller: _searchController,
                  hintText: context.l10n.searchLogs,
                  suffixIcon: Assets.cancel01,
                  onSuffixTap: () {
                    _searchController.clear();
                    model.setQuery('');
                  },
                  onChanged: model.setQuery,
                  textInputAction: .search,
                  onSubmitted: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                ),
              ),
              Expanded(
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    reverse: model.query.trim().isEmpty,
                    padding: .all(Spacing.d16),
                    child:
                        model.visibleLogs.isEmpty &&
                            model.query.trim().isNotEmpty
                        ? Text(context.l10n.noMatchingLogs)
                        : SelectableText(model.visibleLogs),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _logAction(
    BuildContext context,
    String label, {
    required bool enabled,
    required VoidCallback onTap,
  }) => Directionality(
    textDirection: Directionality.of(context),
    child: Semantics(
      button: true,
      enabled: enabled,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: Spacing.d48),
        child: ListItem(
          child: Text(
            label,
            style: context.theme.textTheme.bodyLarge?.copyWith(
              color: enabled
                  ? context.theme.colorScheme.onSurface
                  : context.theme.disabledColor,
            ),
          ),
          onTap: enabled
              ? () {
                  _menuController.close();
                  onTap();
                }
              : null,
        ),
      ),
    ),
  );

  Future<void> _copy(BuildContext context) async {
    try {
      await _model.copyLogs();
      if (context.mounted) context.toastSuccess(context.l10n.logCopied);
    } catch (error, trace) {
      printError(error, trace);
      if (context.mounted) context.toastFailure(Failure(error.toString()));
    }
  }

  Future<void> _export(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final destination = await OutputDestinationPicker.show(context);
    if (!context.mounted || destination == null) return;
    final (path, failure) = await _model.exportLogs(
      context,
      selectedDestination: destination,
    );
    if (!context.mounted) return;
    if (failure != null) {
      context.toastFailure(failure);
    } else if (path != null) {
      context.toastSuccess(context.l10n.logExported(path));
    }
  }
}
