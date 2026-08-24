import 'package:design_system/design_system.dart';
import 'package:flutter/widgets.dart';

class const SectionTitle(
  final String title, {
  super.key,
  final EdgeInsetsGeometry? padding,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          padding ??
          .only(
            left: Spacing.d16,
            right: Spacing.d16,
            top: Spacing.d16,
          ),
      child: Text(
        title,
        style: context.theme.textTheme.titleSmall?.copyWith(
          color: context.theme.primaryColor,
        ),
      ),
    );
  }
}
