import 'package:converter/converter.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:platform_utils/platform_utils.dart';

class OutputFileItem extends StatelessWidget {
  final File file;

  final OutputFormat outputFormat;
  final String? outputFileName;

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
          Column(
            children: [
              FileIcon(file),
              Text(
                outputFormat.fileExtension.toUpperCase(),
              ),
            ],
          ),
          Spacing.h8,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Output file: ${outputFileName ?? 'N/A'}'.hardcode,
                  style: context.theme.textTheme.titleSmall?.copyWith(
                    color: hasError ? context.theme.colorScheme.error : null,
                  ),
                ),
                Text(
                  'Original file: ${basename(file.path)}'.hardcode,
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
