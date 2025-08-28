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

  const JobMakerConfigCustomizer({
    super.key,
    required this.availableControls,
    required this.selectedValues,
    this.onChanged,
    required this.shouldRememberConfigs,
    this.onRememberConfigsChanged,
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
                child: CheckboxListTile(
                  title: Text(context.l10n.rememberConfigsTitle),
                  subtitle: Text(
                    shouldRememberConfigs
                        ? context.l10n.rememberConfigsEnabledSubtitle
                        : context.l10n.rememberConfigsDisabledSubtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  value: shouldRememberConfigs,
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    onRememberConfigsChanged?.call(value);
                  },
                ),
              ),
              const SliverToBoxAdapter(
                child: Divider(),
              ),
              SliverList.separated(
                separatorBuilder: (context, index) => const Divider(),
                itemCount: visibleControls.length,
                itemBuilder: (context, index) {
                  final control = visibleControls.elementAt(index);
                  return ConfigControlWidget(
                    control,
                    selectedValues: selectedValues,
                    onChanged: onChanged,
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
