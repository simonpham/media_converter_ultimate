import 'package:flutter/material.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

/// A filled pill naming an output format, shared by job and preset cards.
class const FormatBadge(
  final String label, {
  super.key,
  required final Color color,
  required final Color onColor,
  final Key? labelKey,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        color: color,
        shape: const RoundedSuperellipseBorder(
          borderRadius: Spacing.r8,
        ),
      ),
      padding: .symmetric(
        horizontal: Spacing.d12,
        vertical: Spacing.d4,
      ),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          key: labelKey,
          label,
          maxLines: 1,
          overflow: .ellipsis,
          style: TextStyle(
            color: onColor,
            fontSize: Spacing.d12,
            fontWeight: .bold,
          ),
        ),
      ),
    );
  }
}
