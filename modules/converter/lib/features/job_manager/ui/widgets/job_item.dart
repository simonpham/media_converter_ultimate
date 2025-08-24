import 'package:converter/converter.dart';
import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:utils/utils.dart';

class JobItem extends StatelessWidget {
  final ConvertJob job;

  final VoidCallback? onRemoveItem;
  final VoidCallback? onOpenLogs;
  final VoidCallback? onShare;
  final VoidCallback? onOpenFile;
  final VoidCallback? onOpenFolder;
  final VoidCallback? onDelete;

  final VoidCallback? onStop;

  const JobItem(
    this.job, {
    this.onRemoveItem,
    this.onOpenLogs,
    this.onShare,
    this.onOpenFile,
    this.onOpenFolder,
    this.onDelete,
    this.onStop,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: Spacing.d16,
      ),
      decoration: ShapeDecoration(
        color: context.theme.colorScheme.surface,
        shape: const SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius.all(
            SmoothRadius(
              cornerRadius: 12.0,
              cornerSmoothing: 1.0,
            ),
          ),
        ),
      ),
      padding: EdgeInsets.symmetric(
        vertical: Spacing.d16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Spacing.d16,
            ),
            child: Row(
              children: [
                JobFileFormatIndicator(
                  outputFileName: job.outputFileName,
                  status: job.status,
                ),
                Spacing.h8,
                Expanded(
                  child: Text(
                    job.outputFileName,
                    style: TextStyle(
                      fontSize: Spacing.d14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Spacing.h8,
                Button(
                  mainAxisSize: MainAxisSize.min,
                  variant: ButtonVariant.ghost,
                  padding: EdgeInsets.all(Spacing.d8),
                  child: ImageView(
                    Assets.hugeicons.stroke.addRemoveDelete.cancel01,
                    size: Spacing.d16,
                    color: context.theme.colorScheme.onSurface,
                  ),
                  onPressed: onRemoveItem,
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Spacing.d16,
            ),
            child: Text.rich(
              TextSpan(
                text: context.l10n.statusPrefix,
                children: [
                  TextSpan(
                    text: job.status.getLabel(context),
                    style: TextStyle(
                      color: job.status.getColor(),
                    ),
                  ),
                ],
              ),
              style: TextStyle(
                fontSize: Spacing.d12,
                color: Colors.grey,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Spacing.d16,
            ),
            child: Text(
              context.l10n.inputFile(basename(job.inputFilePath)),
              style: TextStyle(
                fontSize: Spacing.d12,
                color: Colors.grey,
              ),
            ),
          ),
          Spacing.v4,
          if ((job.progress, job.duration) case (
            int progress,
            int duration,
          ) when job.status.isProcessing) ...[
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: Spacing.d16,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: progress / duration,
                      color: JobStatus.running.getColor(),
                      borderRadius: BorderRadius.circular(Spacing.d4),
                      backgroundColor: JobStatus.running.getColor().withValues(
                        alpha: 0.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Spacing.v16,
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Spacing.d16,
            ),
            child: JobActionBar(
              job,
              onOpenLogs: onOpenLogs,
              onShare: onShare,
              onOpenFile: onOpenFile,
              onOpenFolder: onOpenFolder,
              onDelete: onDelete,
              onStop: onStop,
            ),
          ),
        ],
      ),
    );
  }
}
