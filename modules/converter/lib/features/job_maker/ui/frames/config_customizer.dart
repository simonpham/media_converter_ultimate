import 'package:converter/converter.dart';
import 'package:flutter/material.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

class const JobMakerConfigCustomizer({
  super.key,
  required final List<ConfigControl> availableControls,
  required final Map<String, String> selectedValues,
  final void Function(String, String)? onChanged,
  required final bool shouldRememberConfigs,
  final ValueChanged<bool>? onRememberConfigsChanged,
}) extends StatefulWidget {
  @override
  State<JobMakerConfigCustomizer> createState() =>
      _JobMakerConfigCustomizerState();
}

class _JobMakerConfigCustomizerState extends State<JobMakerConfigCustomizer> {
  final ScrollController _scrollController = .new();

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
                  child: Padding(
                    padding: .all(Spacing.d16),
                    child: const ConversionPresetPicker(
                      currentFormatOnly: true,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: RoundCard(
                    margin: .symmetric(
                      horizontal: Spacing.d16,
                    ),
                    padding: .symmetric(
                      vertical: Spacing.d12,
                    ),
                    child: CheckBoxListTile(
                      alignment: .left,
                      title: context.l10n.rememberConfigsTitle,
                      subtitle: context.l10n.rememberConfigsSubtitle,
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
                      margin: .symmetric(
                        horizontal: Spacing.d16,
                      ),
                      padding: .only(
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
