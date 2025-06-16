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
    final audioFormats = OutputFormat.audioFormats();
    final videoFormats = OutputFormat.videoFormats();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Selector<JobMakerViewModel, OutputFormat?>(
            selector: (context, model) => model.outputFormat,
            builder: (context, selectedFormat, _) {
              return ListView(
                padding: EdgeInsets.symmetric(
                  vertical: Spacing.d16,
                  horizontal: Spacing.d16,
                ),
                children: [
                  _buildGridCategory(
                    context,
                    'Video'.hardcode,
                    videoFormats,
                    selectedFormat,
                  ),
                  Spacing.v16,
                  _buildGridCategory(
                    context,
                    'Audio'.hardcode,
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
    List<OutputFormat> formats,
    OutputFormat? selectedFormat,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            bottom: Spacing.d16,
          ),
          child: Text(
            label,
            style: context.theme.textTheme.titleSmall?.copyWith(
              color: context.theme.primaryColor,
            ),
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
              format: format,
              isSelected: isSelected,
              onTap: () {
                context.read<JobMakerViewModel>().setOutputFormat(format);
              },
            );
          },
        ),
      ],
    );
  }
}
