import 'package:converter/converter.dart';
import 'package:flutter/material.dart';

class const JobFileFormatIndicator({
  super.key,
  required final String outputFileExtension,
  required final JobStatus status,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FormatBadge(
      outputFileExtension.toUpperCase(),
      color: status.getColor(context),
      onColor: status.getOnColor(context),
    );
  }
}
