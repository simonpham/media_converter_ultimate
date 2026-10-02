import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:icons/icons.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

class const JobActionBar({
  super.key,
  final VoidCallback? onOpenLogs,
  final VoidCallback? onShare,
  final VoidCallback? onOpenFile,
  final VoidCallback? onOpenFolder,
  final VoidCallback? onDelete,
  final VoidCallback? onStop,
  final VoidCallback? onRestart,
  final VoidCallback? onRetryExport,
  final VoidCallback? onRenameOutputFile,
  final VoidCallback? onSelectNewOutputPath,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: .start,
      children: [
        if (onOpenLogs != null) ...[
          Button(
            mainAxisSize: .min,
            variant: .ghost,
            tooltip: context.l10n.viewLogs,
            padding: .all(Spacing.d8),
            child: ImageView(
              Assets.note01,
              size: Spacing.d16,
              color: context.theme.colorScheme.onSurface,
            ),
            onPressed: onOpenLogs,
          ),
          Spacing.h8,
        ],
        Expanded(
          child: Wrap(
            alignment: .end,
            spacing: Spacing.d8,
            runSpacing: Spacing.d8,
            children: [
              if (onShare != null) ...[
                Button(
                  mainAxisSize: .min,
                  variant: .ghost,
                  tooltip: context.l10n.shareFile,
                  padding: .all(Spacing.d8),
                  child: ImageView(
                    Assets.share01,
                    size: Spacing.d16,
                    color: context.theme.colorScheme.onSurface,
                  ),
                  onPressed: onShare,
                ),
              ],
              if (onOpenFile != null) ...[
                Button(
                  mainAxisSize: .min,
                  variant: .ghost,
                  tooltip: context.l10n.openFile,
                  padding: .all(Spacing.d8),
                  child: ImageView(
                    Assets.share05,
                    size: Spacing.d16,
                    color: context.theme.colorScheme.onSurface,
                  ),
                  onPressed: onOpenFile,
                ),
              ],
              if (onOpenFolder != null) ...[
                Button(
                  mainAxisSize: .min,
                  variant: .ghost,
                  tooltip: context.l10n.openFolder,
                  padding: .all(Spacing.d8),
                  child: ImageView(
                    Assets.folderOpen,
                    size: Spacing.d16,
                    color: context.theme.colorScheme.onSurface,
                  ),
                  onPressed: onOpenFolder,
                ),
              ],
              if (onDelete != null) ...[
                Button(
                  mainAxisSize: .min,
                  variant: .ghost,
                  tooltip: context.l10n.delete,
                  padding: .all(Spacing.d8),
                  child: ImageView(
                    Assets.delete01,
                    size: Spacing.d16,
                    color: context.theme.colorScheme.error,
                  ),
                  onPressed: onDelete,
                ),
              ],
              if (onStop != null) ...[
                Button(
                  mainAxisSize: .min,
                  titleExpand: .shrink,
                  variant: .ghost,
                  padding: .symmetric(
                    vertical: Spacing.d4,
                    horizontal: Spacing.d8,
                  ),
                  icon: ImageView(
                    Assets.stop,
                    size: Spacing.d16,
                    color: context.theme.colorScheme.error,
                  ),
                  child: Text(
                    context.l10n.stop,
                    style: context.theme.textTheme.bodyMedium?.copyWith(
                      color: context.theme.colorScheme.error,
                    ),
                  ),
                  onPressed: onStop,
                ),
              ],
              if (onRestart != null) ...[
                Button(
                  mainAxisSize: .min,
                  titleExpand: .shrink,
                  variant: .ghost,
                  padding: .all(Spacing.d8),
                  icon: ImageView(
                    Assets.reload,
                    size: Spacing.d16,
                    color: JobStatus.completed.getColor(context),
                  ),
                  child: Text(
                    context.l10n.restart,
                    style: context.theme.textTheme.bodyMedium?.copyWith(
                      color: JobStatus.completed.getColor(context),
                    ),
                  ),
                  onPressed: onRestart,
                ),
              ],
              if (onRetryExport != null)
                Button(
                  mainAxisSize: .min,
                  titleExpand: .shrink,
                  variant: .ghost,
                  padding: .all(Spacing.d8),
                  label: context.l10n.outputRetryExport,
                  icon: ImageView(
                    Assets.reload,
                    size: Spacing.d16,
                    color: context.theme.colorScheme.primary,
                  ),
                  onPressed: onRetryExport,
                ),
              if (onRenameOutputFile != null) ...[
                Button(
                  mainAxisSize: .min,
                  titleExpand: .shrink,
                  variant: .ghost,
                  padding: .all(Spacing.d8),
                  icon: ImageView(
                    Assets.edit02,
                    size: Spacing.d16,
                    color: context.theme.colorScheme.onSurface,
                  ),
                  child: Text(
                    context.l10n.rename,
                    style: context.theme.textTheme.bodyMedium?.copyWith(
                      color: context.theme.colorScheme.onSurface,
                    ),
                  ),
                  onPressed: onRenameOutputFile,
                ),
              ],
              if (onSelectNewOutputPath != null) ...[
                Button(
                  mainAxisSize: .min,
                  titleExpand: .shrink,
                  variant: .ghost,
                  padding: .all(Spacing.d8),
                  icon: ImageView(
                    Assets.folderOpen,
                    size: Spacing.d16,
                    color: context.theme.colorScheme.onSurface,
                  ),
                  child: Text(
                    context.l10n.selectFolder,
                    style: context.theme.textTheme.bodyMedium?.copyWith(
                      color: context.theme.colorScheme.onSurface,
                    ),
                  ),
                  onPressed: onSelectNewOutputPath,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
