import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

class OutputFormatGridItem extends StatelessWidget {
  final FormatConfigModel config;
  final FormatEntry format;
  final bool isSelected;
  final VoidCallback? onTap;

  const OutputFormatGridItem({
    super.key,
    required this.config,
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
            gradient: config.getGradient(format),
            shape: const RoundedSuperellipseBorder(
              borderRadius: Spacing.r12,
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
          child: Stack(
            children: [
              AnimatedScale(
                scale: isSelected ? 1 : 0,
                curve: Curves.easeOut,
                duration: Durations.medium1,
                alignment: Alignment.center,
                child: Container(
                  margin: EdgeInsets.only(
                    left: Spacing.d8,
                    top: Spacing.d8,
                  ),
                  width: Spacing.d12,
                  height: Spacing.d12,
                  decoration: BoxDecoration(
                    color: context.theme.colorScheme.surface,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Center(
                child: Text(
                  format.outputExtension.toUpperCase(),
                  style: context.theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                    fontSize: Spacing.d20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
