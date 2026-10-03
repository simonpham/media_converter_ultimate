import 'package:converter/converter.dart';
import 'package:flutter/material.dart';
import 'package:icons/icons.dart';
import 'package:platform_utils/platform_utils.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

class const FileItem(
  final File file, {
  super.key,
  final FileContentType contentType = .other,
  final Widget? leading,
  final VoidCallback? onRemove,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        color: context.theme.cardColor,
        shape: const RoundedSuperellipseBorder(
          borderRadius: Spacing.r12,
        ),
      ),
      padding: .symmetric(
        horizontal: Spacing.d4,
        vertical: Spacing.d4,
      ),
      child: Row(
        children: [
          Spacing.h8,
          if (leading case Widget leading) ...[
            leading,
            Spacing.h8,
          ],
          FileIcon(contentType),
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
              mainAxisSize: .min,
              variant: .ghost,
              tooltip: context.l10n.removeSelectedFile,
              padding: .all(Spacing.d10),
              child: ImageView(
                Assets.cancel01,
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
