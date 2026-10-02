import 'package:converter/converter.dart';
import 'package:flutter/widgets.dart';

enum JobMakerSteps {
  pickFiles,
  chooseOutputFormat,
  customizeConfigs,
  preview;

  bool get isLastStep => index == JobMakerSteps.values.length - 1;

  Widget build(BuildContext context, {bool showPresetSelection = false}) {
    return switch (this) {
      .pickFiles => const JobMakerFilePicker(),
      .chooseOutputFormat => const JobMakerOutputFormatPicker(),
      .customizeConfigs => Consumer<JobMakerViewModel>(
        builder: (context, model, _) {
          final availableControls = model.availableControls;
          if (availableControls.isEmpty) {
            return const SizedBox();
          }

          return JobMakerConfigCustomizer(
            showPresetSelection: showPresetSelection,
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
      .preview => const JobMakerPreview(),
    };
  }

  String getTitle(BuildContext context) {
    return switch (this) {
      .pickFiles => context.l10n.pickFiles,
      .chooseOutputFormat => context.l10n.chooseOutputFormat,
      .customizeConfigs => context.l10n.customizeConfigs,
      .preview => context.l10n.preview,
    };
  }
}
