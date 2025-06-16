import 'package:converter/converter.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

class JobActionBar extends StatelessWidget {
  final ConvertJob job;

  final VoidCallback? onOpenLogs;
  final VoidCallback? onShare;
  final VoidCallback? onOpenFile;
  final VoidCallback? onOpenFolder;
  final VoidCallback? onDelete;

  const JobActionBar(
    this.job, {
    this.onOpenLogs,
    this.onShare,
    this.onOpenFile,
    this.onOpenFolder,
    this.onDelete,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
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
        const Spacer(),
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
    );
  }
}
