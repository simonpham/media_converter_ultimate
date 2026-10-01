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
          ),
          body: Column(
            children: [
              Padding(
                padding: .all(Spacing.d16),
                child: Column(
                  children: [
                    InputText(
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
                    Spacing.v12,
                    Wrap(
                      spacing: Spacing.d8,
                      runSpacing: Spacing.d8,
                      children: [
                        Button(
                          variant: .ghost,
                          label: context.l10n.copyFullLog,
                          titleExpand: .shrink,
                          enable: model.logs.isNotEmpty,
                          onPressed: () => unawaited(_copy(context)),
                        ),
                        Button(
                          variant: .ghost,
                          label: context.l10n.exportFullLog,
                          titleExpand: .shrink,
                          enable: model.logs.isNotEmpty && !model.isExporting,
                          onPressed: () => unawaited(_export(context)),
                        ),
                      ],
                    ),
                  ],
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
    final (path, failure) = await _model.exportLogs(context);
    if (!context.mounted) return;
    if (failure != null) {
      context.toastFailure(failure);
    } else if (path != null) {
      context.toastSuccess(context.l10n.logExported(path));
    }
  }
}
