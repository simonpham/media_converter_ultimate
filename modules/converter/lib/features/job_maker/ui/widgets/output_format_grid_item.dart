import 'package:converter/converter.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

class OutputFormatGridItem extends StatelessWidget {
  final OutputFormat format;
  final bool isSelected;
  final VoidCallback? onTap;

  const OutputFormatGridItem({
    super.key,
    required this.format,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tappable(
      onTap: onTap,
      enableAnimation: true,
      enableHoverOverlay: false,
      enableFocusBorder: false,
      child: AnimatedScale(
        scale: isSelected ? 1.08 : 0.96,
        duration: Durations.medium4,
        curve: Curves.easeOut,
        child: Container(
          decoration: ShapeDecoration(
            gradient: LinearGradient(
              colors: format.getGradient(),
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: SmoothRectangleBorder(
              borderRadius: Spacing.smoothR12,
            ),
            shadows: isSelected
                ? [
                    BoxShadow(
                      color: context.theme.colorScheme.shadow.withValues(
                        alpha: 0.05,
                      ),
                      blurRadius: Spacing.d1,
                      spreadRadius: Spacing.d1,
                      offset: Offset(0, Spacing.d1),
                    ),
                    BoxShadow(
                      color: context.theme.colorScheme.shadow.withValues(
                        alpha: 0.1,
                      ),
                      blurRadius: Spacing.d2,
                      spreadRadius: Spacing.d1,
                      offset: Offset(Spacing.d1, Spacing.d2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              format.fileExtension.toUpperCase(),
              style: context.theme.textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontSize: Spacing.d20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
