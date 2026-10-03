import 'package:converter/converter.dart';
import 'package:flutter/material.dart';
import 'package:icons/icons.dart';
import 'package:platform_utils/platform_utils.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

class const OutputFileItem(
  final File file, {
  super.key,
  required final int index,
  required final FormatEntry outputFormat,
  required final String outputFileName,
  final Failure? failure,
  final VoidCallback? onRenamePressed,
  final ConversionTrim? trim,
  final VoidCallback? onTrimPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final hasError = failure != null;
    return Tappable(
      behavior: .translucent,
      tooltip:
          '$outputFileName'
          '\n'
          '${context.l10n.originalFile(basename(file.path))}',
      onTap: switch (failure) {
        Failure f => () => context.toastFailure(f),
        _ => null,
      },
      child: Container(
        decoration: ShapeDecoration(
          color: context.theme.cardColor,
          shape: const RoundedSuperellipseBorder(
            borderRadius: Spacing.r12,
          ),
        ),
        padding: .symmetric(horizontal: Spacing.d8, vertical: Spacing.d4),
        child: Row(
          children: [
            Spacing.h8,
            Text(
              '$index',
              style: context.theme.textTheme.bodyMedium?.copyWith(
                fontWeight: .bold,
                color: hasError ? context.theme.colorScheme.error : null,
              ),
            ),
            Spacing.h8,
            Expanded(
              child: Column(
                mainAxisSize: .min,
                crossAxisAlignment: .start,
                children: [
                  Text(
                    outputFileName,
                    style: context.theme.textTheme.bodyMedium?.copyWith(
                      color: hasError ? context.theme.colorScheme.error : null,
                    ),
                    maxLines: 2,
                    overflow: .ellipsis,
                  ),
                  if (trim case final range?) ...[
                    Spacing.v4,
                    Text(
                      context.l10n.trimRangeSummary(
                        MediaTimestamp.display(range.start),
                        range.end == null
                            ? context.l10n.trimEndOfFile
                            : MediaTimestamp.display(range.end!),
                      ),
                      style: context.theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            Spacing.h8,
            _action(
              context,
              key: ValueKey('rename-file-${file.path}'),
              tooltip: context.l10n.rename,
              asset: Assets.edit02,
              onTap: onRenamePressed,
              color: hasError
                  ? context.theme.colorScheme.error
                  : context.theme.colorScheme.primary,
            ),
            if (onTrimPressed != null || trim != null)
              _action(
                context,
                key: ValueKey('trim-file-${file.path}'),
                tooltip: context.l10n.trimMediaTitle,
                asset: Assets.scissor,
                onTap: onTrimPressed,
                color: context.theme.colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }

  Widget _action(
    BuildContext context, {
    required Key key,
    required String tooltip,
    required String asset,
    required VoidCallback? onTap,
    required Color color,
  }) => Semantics(
    button: true,
    enabled: onTap != null,
    child: Tappable(
      key: key,
      tooltip: tooltip,
      onTap: onTap,
      child: Padding(
        padding: .all(Spacing.d12),
        child: ImageView(asset, size: Spacing.d20, color: color),
      ),
    ),
  );
}
