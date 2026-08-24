import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

class JobFileFormatIndicator extends StatelessWidget {
  final String outputFileExtension;
  final JobStatus status;

  const JobFileFormatIndicator({
    super.key,
    required this.outputFileExtension,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final fileExtension = outputFileExtension.toUpperCase();
    return Container(
      decoration: ShapeDecoration(
        color: status.getColor(),
        shape: const RoundedSuperellipseBorder(
          borderRadius: Spacing.r8,
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: Spacing.d12,
        vertical: Spacing.d4,
      ),
      child: Center(
        child: Text(
          fileExtension,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
