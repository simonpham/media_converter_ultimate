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
            onChanged: (name, value) {
              model.setSelectedValue(name, value);
            },
          );
        },
      ),
      preview => const JobMakerPreview(),
    };
  }

  String getTitle(BuildContext context) {
    return switch (this) {
      JobMakerSteps.pickFiles => 'Pick files'.hardcode,
      JobMakerSteps.chooseOutputFormat => 'Choose output format'.hardcode,
      JobMakerSteps.customizeConfigs => 'Customize configs'.hardcode,
      JobMakerSteps.preview => 'Preview'.hardcode,
    };
  }
}
