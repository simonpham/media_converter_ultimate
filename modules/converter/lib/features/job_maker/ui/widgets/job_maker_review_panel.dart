import 'package:converter/converter.dart';
import 'package:flutter/material.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

/// Keeps the conversion choices in view beside the wizard on wide screens.
class const JobMakerReviewPanel({super.key}) extends StatefulWidget {
  @override
  State<JobMakerReviewPanel> createState() => _JobMakerReviewPanelState();
}

class _JobMakerReviewPanelState extends State<JobMakerReviewPanel> {
  final ScrollController _scrollController = .new();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scrollbar(
    controller: _scrollController,
    thumbVisibility: true,
    child: SingleChildScrollView(
      controller: _scrollController,
      child: Consumer<JobMakerViewModel>(
        builder: (context, model, _) => Column(
          crossAxisAlignment: .stretch,
          children: [
            // ConversionSummary appears once a format is chosen.
            if (model.selectedFormatEntry == null)
              RoundCard(
                margin: .all(Spacing.d16),
                padding: .all(Spacing.d16),
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    Text(
                      context.l10n.conversionSummary,
                      style: context.theme.textTheme.titleMedium,
                    ),
                    Spacing.v8,
                    Text(
                      context.l10n.selectedFiles(model.selectedFiles.length),
                      style: context.theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            const ConversionSummary(),
          ],
        ),
      ),
    ),
  );
}
