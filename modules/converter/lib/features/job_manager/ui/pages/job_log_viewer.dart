import 'package:converter/converter.dart'
    show LogDataExt, LogData, LogDataBoxExt;
import 'package:core/core.dart';
import 'package:flutter/material.dart';
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.job.outputFileName),
      ),
      body: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scrollController,
          reverse: true,
          padding: .all(Spacing.d16),
          child: ValueListenableBuilder(
            valueListenable: LogData().getLogListenable(widget.job.id),
            builder: (context, _, child) {
              return SelectableText(widget.job.logs);
            },
          ),
        ),
      ),
    );
  }
}
