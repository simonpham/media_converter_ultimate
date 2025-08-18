import 'package:converter/converter.dart';
import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:platform_utils/platform_utils.dart';

class OutputFileItem extends StatelessWidget {
  final File file;

  final FormatEntry outputFormat;
  final String outputFileName;

  final bool hasError;

  const OutputFileItem(
    this.file, {
    super.key,
    required this.outputFormat,
    required this.outputFileName,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Button(
      enable: false,
      enableHover: false,
      variant: ButtonVariant.ghost,
      padding: EdgeInsets.symmetric(
        horizontal: Spacing.d16,
        vertical: Spacing.d12,
      ),
      icon: Padding(
        padding: EdgeInsets.only(right: Spacing.d4),
        child: Column(
          children: [
            FileIcon(file),
            Text(
              outputFormat.outputExtension.toUpperCase(),
            ),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            outputFileName,
            style: context.theme.textTheme.titleSmall?.copyWith(
              color: hasError ? context.theme.colorScheme.error : null,
            ),
          ),
          Text(
            context.l10n.originalFile(basename(file.path)),
            style: context.theme.textTheme.bodySmall,
          ),
        ],
      ),
      labelTextAlign: TextAlign.start,
      expandTitle: true,
      trailingIcon: Tappable(
        behavior: HitTestBehavior.translucent,
        tooltip: context.l10n.rename,
        onTap: () {},
        child: Container(
          padding: EdgeInsets.all(
            Spacing.d12,
          ),
          child: ImageView(
            Assets.hugeicons.stroke.editFormatting.edit02,
            color: hasError
                ? context.theme.colorScheme.error
                : context.theme.colorScheme.primary,
            size: Spacing.d20,
          ),
        ),
      ),
      mainAxisAlignment: MainAxisAlignment.start,
    );
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
        vertical: Spacing.d12,
      ),
      child: Row(
        children: [
          Spacing.h8,
          Column(
            children: [
              FileIcon(file),
              Text(
                outputFormat.outputExtension.toUpperCase(),
              ),
            ],
          ),
          Spacing.h8,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.outputFile(outputFileName ?? 'N/A'),
                  style: context.theme.textTheme.titleSmall?.copyWith(
                    color: hasError ? context.theme.colorScheme.error : null,
                  ),
                ),
                Text(
                  context.l10n.originalFile(basename(file.path)),
                  style: context.theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
