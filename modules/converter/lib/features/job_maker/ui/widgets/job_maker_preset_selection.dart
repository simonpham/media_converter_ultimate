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
        child: Text(
          preset == null
              ? context.l10n.choosePreset
              : '${preset.getTitle(context)} · ${context.l10n.changePreset}',
          textAlign: .start,
        ),
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
    },
  );
}
