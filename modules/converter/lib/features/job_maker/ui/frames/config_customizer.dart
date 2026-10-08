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
  final bool showPresetSelection = false,
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
    final columns = switch (context.screenSize) {
      .small || .normal => 1,
      .large || .larger || .extraLarge => 2,
    };
    return Column(
      children: [
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(child: Spacing.v16),
                if (widget.showPresetSelection) ...[
                  SliverPadding(
                    padding: .symmetric(horizontal: Spacing.d16),
                    sliver: const SliverToBoxAdapter(
                      child: JobMakerPresetSelection(),
                    ),
                  ),
                  SliverToBoxAdapter(child: Spacing.v16),
                ],
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
                if (columns == 1)
                  SliverList.separated(
                    separatorBuilder: (context, index) => Spacing.v16,
                    itemCount: visibleControls.length,
                    itemBuilder: (context, index) => _buildControlCard(
                      context,
                      visibleControls.elementAt(index),
                    ),
                  )
                else
                  // Rows keep the controls in reading order across columns.
                  SliverList.separated(
                    separatorBuilder: (context, index) => Spacing.v16,
                    itemCount: (visibleControls.length / columns).ceil(),
                    itemBuilder: (context, row) => Padding(
                      padding: .symmetric(
                        horizontal: Spacing.d16,
                      ),
                      child: Row(
                        crossAxisAlignment: .start,
                        spacing: Spacing.d16,
                        children: [
                          for (var column = 0; column < columns; column++)
                            Expanded(
                              child: switch (row * columns + column) {
                                final index
                                    when index < visibleControls.length =>
                                  _buildControlCard(
                                    context,
                                    visibleControls.elementAt(index),
                                    margin: .zero,
                                  ),
                                _ => const SizedBox.shrink(),
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: Spacing.d12 * 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControlCard(
    BuildContext context,
    ConfigControl control, {
    EdgeInsetsGeometry? margin,
  }) {
    return Container(
      margin:
          margin ??
          .symmetric(
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
  }
}
