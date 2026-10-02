import 'package:converter/converter.dart';
import 'package:flutter/material.dart';
import 'package:icons/icons.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

/// A compact entry to the shared chooser; preset cards stay out of the steps.
class const JobMakerPresetSelection({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Consumer<JobMakerViewModel>(
    builder: (context, model, _) {
      if (model.availablePresets.isEmpty) return const SizedBox.shrink();
      final preset = model.selectedPreset;
      final action = Button(
        key: const ValueKey('choose-conversion-preset'),
        variant: .ghost,
        mainAxisSize: .min,
        titleExpand: .shrink,
        padding: .symmetric(horizontal: Spacing.d12, vertical: Spacing.d8),
        enable: !model.isLoadingFormat && !model.isPreparingJobs,
        label: preset == null
            ? context.l10n.choosePreset
            : context.l10n.changePreset,
        onPressed: () async {
          final selection = await ConversionPresetPicker.show(
            context,
            presets: model.availablePresets,
            selectedPreset: preset,
          );
          if (!context.mounted || selection == null) return;
          if (selection == model.selectedPreset) {
            model.clearPreset();
          } else {
            await model.applyPreset(selection);
          }
        },
      );
      if (preset == null) {
        return Button(
          key: const ValueKey('choose-conversion-preset'),
          variant: .ghost,
          titleExpand: .expand,
          enable: !model.isLoadingFormat && !model.isPreparingJobs,
          icon: ImageView(
            Assets.flash,
            size: Spacing.d24,
            color: context.theme.colorScheme.primary,
          ),
          child: Text(context.l10n.choosePreset, textAlign: .start),
          onPressed: action.onPressed,
        );
      }
      final title = Row(
        children: [
          ImageView(
            Assets.flash,
            size: Spacing.d24,
            color: context.theme.colorScheme.primary,
          ),
          Spacing.h12,
          Expanded(
            child: Text(
              preset.getTitle(context),
              style: context.theme.textTheme.titleSmall,
            ),
          ),
        ],
      );
      return RoundCard(
        padding: .all(Spacing.d16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale =
                MediaQuery.textScalerOf(context).scale(Spacing.d12) /
                Spacing.d12;
            if (constraints.maxWidth < Spacing.d96 * 3 * scale) {
              return Column(
                crossAxisAlignment: .stretch,
                children: [
                  title,
                  Spacing.v12,
                  Align(alignment: .centerRight, child: action),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: title),
                Spacing.h12,
                action,
              ],
            );
          },
        ),
      );
    },
  );
}
