import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

class const JobFileFormatIndicator({
  super.key,
  required final String outputFileExtension,
  required final JobStatus status,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final fileExtension = outputFileExtension.toUpperCase();
    return Container(
      decoration: ShapeDecoration(
        color: status.getColor(context),
        shape: const RoundedSuperellipseBorder(
          borderRadius: Spacing.r8,
        ),
      ),
      padding: .symmetric(
        horizontal: Spacing.d12,
        vertical: Spacing.d4,
      ),
      child: Center(
        child: Text(
          fileExtension,
          style: TextStyle(
            color: status.getOnColor(context),
            fontSize: Spacing.d12,
            fontWeight: .bold,
          ),
        ),
      ),
    );
  }
}
