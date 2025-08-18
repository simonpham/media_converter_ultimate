import 'package:design_system/design_system.dart';
import 'package:flutter/widgets.dart';

class SectionTitle extends StatelessWidget {
  final String title;

  final EdgeInsetsGeometry? padding;

  const SectionTitle(
    this.title, {
    super.key,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          padding ??
          EdgeInsets.only(
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
