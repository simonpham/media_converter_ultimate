import 'package:converter/converter.dart';
import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

class JobMakerOutputFormatPicker extends StatelessWidget {
  const JobMakerOutputFormatPicker({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final formatConfigModel = context
        .read<JobMakerViewModel>()
        .formatConfigModel;
    final audioFormats = formatConfigModel.formats
        .where((f) => f.outputType == OutputType.audio)
        .toList();
    final videoFormats = formatConfigModel.formats
        .where((f) => f.outputType == OutputType.video)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Selector<JobMakerViewModel, FormatEntry?>(
            selector: (context, model) => model.selectedFormatEntry,
            builder: (context, selectedFormat, _) {
              return ListView(
                padding: EdgeInsets.symmetric(
                  vertical: Spacing.d16,
                  horizontal: Spacing.d16,
                ),
                children: [
                  _buildGridCategory(
                    context,
                    context.l10n.video,
                    formatConfigModel,
                    videoFormats,
                    selectedFormat,
                  ),
                  Spacing.v16,
                  _buildGridCategory(
                    context,
                    context.l10n.audio,
                    formatConfigModel,
                    audioFormats,
                    selectedFormat,
                  ),
                ],
              );
            },
          ),
        ),
        const BottomSpacer(),
      ],
    );
  }

  Widget _buildGridCategory(
    BuildContext context,
    String label,
    FormatConfigModel config,
    List<FormatEntry> formats,
    FormatEntry? selectedFormat,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          label,
          padding: EdgeInsets.only(
            bottom: Spacing.d16,
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: Spacing.d16,
            crossAxisSpacing: Spacing.d16,
            childAspectRatio: 1,
          ),
          itemCount: formats.length,
          itemBuilder: (context, index) {
            final format = formats[index];
            final isSelected = selectedFormat == format;
            return OutputFormatGridItem(
              config: config,
              format: format,
              isSelected: isSelected,
              onTap: () {
                context.read<JobMakerViewModel>().setSelectedFormatEntry(
                  format,
                );
              },
            );
          },
        ),
      ],
    );
  }
}
