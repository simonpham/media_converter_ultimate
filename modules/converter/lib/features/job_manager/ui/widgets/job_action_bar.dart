import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:icons/icons.dart';

class JobActionBar extends StatelessWidget {
  final VoidCallback? onOpenLogs;
  final VoidCallback? onShare;
  final VoidCallback? onOpenFile;
  final VoidCallback? onOpenFolder;
  final VoidCallback? onDelete;
  final VoidCallback? onStop;
  final VoidCallback? onRestart;
  final VoidCallback? onRenameOutputFile;
  final VoidCallback? onSelectNewOutputPath;

  const JobActionBar({
    this.onOpenLogs,
    this.onShare,
    this.onOpenFile,
    this.onOpenFolder,
    this.onDelete,
    this.onStop,
    this.onRestart,
    this.onRenameOutputFile,
    this.onSelectNewOutputPath,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onOpenLogs != null) ...[
          Button(
            mainAxisSize: MainAxisSize.min,
            variant: ButtonVariant.ghost,
            padding: EdgeInsets.all(Spacing.d8),
            child: ImageView(
              Assets.note01,
              size: Spacing.d16,
              color: context.theme.colorScheme.onSurface,
            ),
            onPressed: onOpenLogs,
          ),
          Spacing.h8,
        ],
        const Spacer(),
        if (onShare != null) ...[
          Spacing.h8,
          Button(
            mainAxisSize: MainAxisSize.min,
            variant: ButtonVariant.ghost,
            padding: EdgeInsets.all(Spacing.d8),
            child: ImageView(
              Assets.share01,
              size: Spacing.d16,
              color: context.theme.colorScheme.onSurface,
            ),
            onPressed: onShare,
          ),
        ],
        if (onOpenFile != null) ...[
          Spacing.h8,
          Button(
            mainAxisSize: MainAxisSize.min,
            variant: ButtonVariant.ghost,
            padding: EdgeInsets.all(Spacing.d8),
            child: ImageView(
              Assets.share05,
              size: Spacing.d16,
              color: context.theme.colorScheme.onSurface,
            ),
            onPressed: onOpenFile,
          ),
        ],
        if (onOpenFolder != null) ...[
          Spacing.h8,
          Button(
            mainAxisSize: MainAxisSize.min,
            variant: ButtonVariant.ghost,
            padding: EdgeInsets.all(Spacing.d8),
            child: ImageView(
              Assets.folderOpen,
              size: Spacing.d16,
              color: context.theme.colorScheme.onSurface,
            ),
            onPressed: onOpenFolder,
          ),
        ],
        if (onDelete != null) ...[
          Spacing.h8,
          Button(
            mainAxisSize: MainAxisSize.min,
            variant: ButtonVariant.ghost,
            padding: EdgeInsets.all(Spacing.d8),
            child: ImageView(
              Assets.delete01,
              size: Spacing.d16,
              color: context.theme.colorScheme.error,
            ),
            onPressed: onDelete,
          ),
        ],
        if (onStop != null) ...[
          Spacing.h8,
          Button(
            mainAxisSize: MainAxisSize.min,
            variant: ButtonVariant.ghost,
            padding: EdgeInsets.symmetric(
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
          Spacing.h8,
          Button(
            mainAxisSize: MainAxisSize.min,
            variant: ButtonVariant.ghost,
            padding: EdgeInsets.all(Spacing.d8),
            icon: ImageView(
              Assets.reload,
              size: Spacing.d16,
              color: JobStatus.completed.getColor(),
            ),
            child: Text(
              context.l10n.restart,
              style: context.theme.textTheme.bodyMedium?.copyWith(
                color: JobStatus.completed.getColor(),
              ),
            ),
            onPressed: onRestart,
          ),
        ],
        if (onRenameOutputFile != null) ...[
          Spacing.h8,
          Button(
            mainAxisSize: MainAxisSize.min,
            variant: ButtonVariant.ghost,
            padding: EdgeInsets.all(Spacing.d8),
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
          Spacing.h8,
          Button(
            mainAxisSize: MainAxisSize.min,
            variant: ButtonVariant.ghost,
            padding: EdgeInsets.all(Spacing.d8),
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
    );
  }
}
