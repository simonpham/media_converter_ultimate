import 'package:converter/converter.dart';
import 'package:core/core.dart';
import 'package:flutter/widgets.dart';

enum JobMakerSteps {
  pickFiles,
  chooseOutputFormat,
  customizeConfigs,
  preview;

  bool get isLastStep => index == JobMakerSteps.values.length - 1;

  Widget build(BuildContext context) {
    return switch (this) {
      pickFiles => const JobMakerFilePicker(),
      chooseOutputFormat => const JobMakerOutputFormatPicker(),
      customizeConfigs => Consumer<JobMakerViewModel>(
        builder: (context, model, _) {
          final availableControls = model.availableControls;
          if (availableControls.isEmpty) {
            return const SizedBox();
          }

          return JobMakerConfigCustomizer(
            availableControls: availableControls,
            selectedValues: model.selectedValues,
            shouldRememberConfigs: model.shouldRememberConfigs,
            onChanged: (name, value) {
              model.setSelectedValue(name, value);
            },
            onRememberConfigsChanged: (remember) {
              model.setRememberConfigs(remember);
            },
          );
        },
      ),
      preview => const JobMakerPreview(),
    };
  }

  String getTitle(BuildContext context) {
    return switch (this) {
      JobMakerSteps.pickFiles => context.l10n.pickFiles,
      JobMakerSteps.chooseOutputFormat => context.l10n.chooseOutputFormat,
      JobMakerSteps.customizeConfigs => context.l10n.customizeConfigs,
      JobMakerSteps.preview => context.l10n.preview,
    };
  }
}
