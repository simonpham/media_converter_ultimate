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
          final formatEntry = model.selectedFormatEntry;
          if (formatEntry == null) {
            return const SizedBox();
          }

          final configControls = model.configControls;
          if (configControls.isEmpty) {
            return const SizedBox();
          }

          return JobMakerConfigCustomizer(
            configControls: configControls,
            selectedFormat: formatEntry,
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
