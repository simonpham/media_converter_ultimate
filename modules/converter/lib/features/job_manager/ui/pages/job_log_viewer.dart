import 'package:converter/converter.dart'
    show LogDataExt, LogData, LogDataBoxExt;
import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

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

class JobLogViewer extends StatefulWidget {
  final ConvertJob job;

  const JobLogViewer({
    super.key,
    required this.job,
  });

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
        // TODO: add search.
        // actions: [
        //   IconButton(
        //     onPressed: () {},
        //     icon: ImageView(
        //       Assets.hugeicons.stroke.search.search,
        //       size: Spacing.d24,
        //       color: context.theme.colorScheme.onSurface,
        //     ),
        //   ),
        // ],
      ),
      body: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scrollController,
          reverse: true,
          padding: EdgeInsets.all(Spacing.d16),
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
