import 'package:converter/converter.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:platform_utils/platform_utils.dart';

class FileItem extends StatelessWidget {
  const FileItem(
    this.file, {
    super.key,
    this.onRemove,
  });

  final File file;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
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
        horizontal: Spacing.d4,
        vertical: Spacing.d4,
      ),
      child: Row(
        children: [
          Spacing.h8,
          FileIcon(file),
          Spacing.h8,
          Expanded(
            child: Text(
              basename(file.path),
              style: context.theme.textTheme.bodySmall,
            ),
          ),
          if (onRemove != null) ...[
            Spacing.h8,
            Button(
              mainAxisSize: MainAxisSize.min,
              variant: ButtonVariant.ghost,
              padding: EdgeInsets.all(Spacing.d8),
              child: ImageView(
                Assets.hugeicons.stroke.addRemoveDelete.cancel01,
                size: Spacing.d16,
                color: context.theme.colorScheme.error,
              ),
              onPressed: onRemove,
            ),
          ],
        ],
      ),
    );
  }
}
