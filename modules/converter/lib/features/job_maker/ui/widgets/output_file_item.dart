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
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            Row(
              children: [
                Spacing.h16,
                Text(
                  '$index',
                  style: context.theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: .bold,
                    color: hasError ? context.theme.colorScheme.error : null,
                  ),
                  maxLines: 1,
                ),
                Spacing.h8,
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Text(
                        outputFileName,
                        style: context.theme.textTheme.bodyMedium?.copyWith(
                          color: hasError
                              ? context.theme.colorScheme.error
                              : null,
                        ),
                        maxLines: 1,
                        overflow: .ellipsis,
                      ),
                    ],
                  ),
                ),
                Spacing.h8,
                Tappable(
                  behavior: .translucent,
                  tooltip: context.l10n.rename,
                  onTap: onRenamePressed,
                  child: Container(
                    padding: .all(
                      Spacing.d12,
                    ),
                    child: ImageView(
                      Assets.edit02,
                      color: hasError
                          ? context.theme.colorScheme.error
                          : context.theme.colorScheme.primary,
                      size: Spacing.d20,
                    ),
                  ),
                ),
                Spacing.h4,
              ],
            ),
            if (onTrimPressed != null)
              Padding(
                padding: .only(
                  left: Spacing.d16,
                  right: Spacing.d12,
                  bottom: Spacing.d12,
                ),
                child: Wrap(
                  alignment: .spaceBetween,
                  crossAxisAlignment: .center,
                  spacing: Spacing.d8,
                  runSpacing: Spacing.d8,
                  children: [
                    Text(
                      trim == null
                          ? context.l10n.trimFullFile
                          : context.l10n.trimRangeSummary(
                              MediaTimestamp.display(trim!.start),
                              trim!.end == null
                                  ? context.l10n.trimEndOfFile
                                  : MediaTimestamp.display(trim!.end!),
                            ),
                      style: context.theme.textTheme.bodySmall,
                    ),
                    Button(
                      key: ValueKey('trim-file-${file.path}'),
                      variant: .ghost,
                      label: context.l10n.trimMediaTitle,
                      titleExpand: .shrink,
                      mainAxisSize: .min,
                      onPressed: onTrimPressed,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
