import 'package:flutter/widgets.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

class const SectionTitle(
  final String title, {
  super.key,
  final EdgeInsetsGeometry? padding,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = context.fluffyTheme;
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
        style: theme.typography.headline6.copyWith(
          color: theme.colors.primary,
        ),
      ),
    );
  }
}
