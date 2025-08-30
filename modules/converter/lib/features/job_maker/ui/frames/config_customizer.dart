import 'package:converter/converter.dart';
import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

class JobMakerConfigCustomizer extends StatelessWidget {
  final List<ConfigControl> availableControls;

  final Map<String, String> selectedValues;
  final void Function(String, String)? onChanged;

  final bool shouldRememberConfigs;
  final ValueChanged<bool>? onRememberConfigsChanged;

  final VoidCallback? onResetConfigs;

  const JobMakerConfigCustomizer({
    super.key,
    required this.availableControls,
    required this.selectedValues,
    this.onChanged,
    required this.shouldRememberConfigs,
    this.onRememberConfigsChanged,
    this.onResetConfigs,
  });

  @override
  Widget build(BuildContext context) {
    final visibleControls = availableControls.where(
      (control) => control.isVisible,
    );
    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: RoundCard(
                  margin: EdgeInsets.symmetric(
                    horizontal: Spacing.d16,
                  ),
                  padding: EdgeInsets.symmetric(
                    vertical: Spacing.d12,
                  ),
                  child: Column(
                    children: [
                      CheckBoxListTile(
                        alignment: CheckBoxAlignment.left,
                        title: context.l10n.rememberConfigsTitle,
                        subtitle: shouldRememberConfigs
                            ? context.l10n.rememberConfigsEnabledSubtitle
                            : context.l10n.rememberConfigsDisabledSubtitle,
                        value: shouldRememberConfigs,
                        onChanged: (value) {
                          onRememberConfigsChanged?.call(value);
                        },
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: Spacing.d8,
                          horizontal: Spacing.d16,
                        ),
                        child: Button(
                          variant: ButtonVariant.ghost,
                          label: context.l10n.resetToDefault,
                          onPressed: onResetConfigs,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Spacing.v16,
              ),
              SliverList.separated(
                separatorBuilder: (context, index) => Spacing.v16,
                itemCount: visibleControls.length,
                itemBuilder: (context, index) {
                  final control = visibleControls.elementAt(index);
                  return Container(
                    margin: EdgeInsets.symmetric(
                      horizontal: Spacing.d16,
                    ),
                    padding: EdgeInsets.only(
                      top: Spacing.d8,
                      bottom: Spacing.d12,
                    ),
                    decoration: ShapeDecoration(
                      color: context.theme.cardColor,
                      shape: const SmoothRectangleBorder(
                        borderRadius: SmoothBorderRadius.all(
                          SmoothRadius(
                            cornerRadius: 12.0,
                            cornerSmoothing: 1.0,
                          ),
                        ),
                      ),
                    ),
                    child: ConfigControlWidget(
                      control,
                      selectedValues: selectedValues,
                      onChanged: onChanged,
                    ),
                  );
                },
              ),
              const SliverToBoxAdapter(
                child: BottomSpacer(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
