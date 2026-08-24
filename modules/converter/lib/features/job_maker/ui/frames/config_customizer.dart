import 'package:converter/converter.dart';
import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

class JobMakerConfigCustomizer extends StatefulWidget {
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
  State<JobMakerConfigCustomizer> createState() =>
      _JobMakerConfigCustomizerState();
}

class _JobMakerConfigCustomizerState extends State<JobMakerConfigCustomizer> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleControls = widget.availableControls.where(
      (control) => control.isVisible,
    );
    return Column(
      children: [
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: RoundCard(
                    margin: EdgeInsets.symmetric(
                      horizontal: Spacing.d16,
                    ),
                    padding: EdgeInsets.symmetric(
                      vertical: Spacing.d12,
                    ),
                    child: CheckBoxListTile(
                      alignment: CheckBoxAlignment.left,
                      title: context.l10n.rememberConfigsTitle,
                      subtitle: widget.shouldRememberConfigs
                          ? context.l10n.rememberConfigsEnabledSubtitle
                          : context.l10n.rememberConfigsDisabledSubtitle,
                      value: widget.shouldRememberConfigs,
                      onChanged: (value) {
                        widget.onRememberConfigsChanged?.call(value);
                      },
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
                        shape: const RoundedSuperellipseBorder(
                          borderRadius: Spacing.r12,
                        ),
                      ),
                      child: ConfigControlWidget(
                        control,
                        selectedValues: widget.selectedValues,
                        onChanged: widget.onChanged,
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
        ),
      ],
    );
  }
}
