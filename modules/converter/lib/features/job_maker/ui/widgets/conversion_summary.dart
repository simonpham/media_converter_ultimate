import 'package:converter/converter.dart';
import 'package:flutter/material.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

class const ConversionSummary({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Consumer<JobMakerViewModel>(
    builder: (context, model, _) {
      final format = model.selectedFormatEntry;
      if (format == null) return const SizedBox.shrink();
      final trim = model.selectedTrim;
      return RoundCard(
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
              model.selectedPreset?.getTitle(context) ??
                  context.l10n.customSettings,
              style: context.theme.textTheme.bodyLarge,
            ),
            Spacing.v4,
            Text(
              '${format.outputExtension.toUpperCase()} · ${context.l10n.selectedFiles(model.selectedFiles.length)}',
              style: context.theme.textTheme.bodySmall,
            ),
            for (final setting in model.configurationSummary) ...[
              Spacing.v8,
              Text(
                '${context.configL10n(setting.label)}: ${context.configL10n(setting.value)}',
                style: context.theme.textTheme.bodyMedium,
              ),
            ],
            if (trim != null) ...[
              Spacing.v8,
              Text(
                '${context.l10n.trimMediaTitle}: ${context.l10n.trimRangeSummary(MediaTimestamp.display(trim.start), trim.end == null ? context.l10n.trimEndOfFile : MediaTimestamp.display(trim.end!))}',
                style: context.theme.textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      );
    },
  );
}
