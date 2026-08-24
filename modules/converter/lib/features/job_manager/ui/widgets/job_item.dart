import 'dart:math';

import 'package:converter/converter.dart';
import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:icons/icons.dart';
import 'package:utils/utils.dart';

class const JobItem(
  final ConvertJob job, {
  super.key,
  final VoidCallback? onRemoveItem,
  final VoidCallback? onOpenLogs,
  final VoidCallback? onShare,
  final VoidCallback? onOpenFile,
  final VoidCallback? onOpenFolder,
  final VoidCallback? onDelete,
  final VoidCallback? onStop,
  final VoidCallback? onRestart,
  final VoidCallback? onRenameOutputFile,
  final VoidCallback? onSelectNewOutputPath,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: .symmetric(
        horizontal: Spacing.d16,
      ),
      decoration: ShapeDecoration(
        color: context.theme.cardColor,
        shape: const RoundedSuperellipseBorder(
          borderRadius: Spacing.r12,
        ),
      ),
      padding: .symmetric(
        vertical: Spacing.d16,
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Padding(
            padding: .symmetric(
              horizontal: Spacing.d16,
            ),
            child: Row(
              children: [
                JobFileFormatIndicator(
                  outputFileExtension: job.outputExtension,
                  status: job.status,
                ),
                Spacing.h8,
                Expanded(
                  child: Text(
                    job.outputFileName,
                    style: TextStyle(
                      fontSize: Spacing.d14,
                      fontWeight: .w600,
                    ),
                  ),
                ),
                Spacing.h8,
                Button(
                  mainAxisSize: .min,
                  variant: .ghost,
                  padding: .all(Spacing.d8),
                  child: ImageView(
                    Assets.cancel01,
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
            padding: .symmetric(
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
            padding: .symmetric(
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
          if ((job.progress, job.duration)
              case (
                int progress,
                int duration,
              )
              when job.status.isProcessing && duration > 0) ...[
            Padding(
              padding: .symmetric(
                horizontal: Spacing.d16,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: max(0, min(1.0, progress / duration)),
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
            padding: .symmetric(
              horizontal: Spacing.d16,
            ),
            child: JobActionBar(
              onOpenLogs: onOpenLogs,
              onShare: onShare,
              onOpenFile: onOpenFile,
              onOpenFolder: onOpenFolder,
              onDelete: onDelete,
              onStop: onStop,
              onRestart: onRestart,
              onRenameOutputFile: onRenameOutputFile,
              onSelectNewOutputPath: onSelectNewOutputPath,
            ),
          ),
        ],
      ),
    );
  }
}
