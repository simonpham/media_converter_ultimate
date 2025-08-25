import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

class JobActionBar extends StatelessWidget {
  final VoidCallback? onOpenLogs;
  final VoidCallback? onShare;
  final VoidCallback? onOpenFile;
  final VoidCallback? onOpenFolder;
  final VoidCallback? onDelete;
  final VoidCallback? onStop;

  const JobActionBar({
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
    return Row(
      children: [
        if (onOpenLogs != null) ...[
          Button(
            mainAxisSize: MainAxisSize.min,
            variant: ButtonVariant.ghost,
            padding: EdgeInsets.all(Spacing.d8),
            child: ImageView(
              Assets.hugeicons.stroke.noteTask.note01,
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
              Assets.hugeicons.stroke.linkUnlink.share01,
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
              Assets.hugeicons.stroke.linkUnlink.share05,
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
              Assets.hugeicons.stroke.filesFolders.folderOpen,
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
              Assets.hugeicons.stroke.addRemoveDelete.delete01,
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
              Assets.hugeicons.stroke.media.stop,
              size: Spacing.d16,
              color: context.theme.colorScheme.error,
            ),
            child: Text(
              'Stop',
              style: context.theme.textTheme.bodyMedium?.copyWith(
                color: context.theme.colorScheme.error,
              ),
            ),
            onPressed: onStop,
          ),
        ],
      ],
    );
  }
}
