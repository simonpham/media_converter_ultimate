import 'package:converter/converter.dart';
import 'package:flutter/material.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';
import 'package:utils/utils.dart';

class const JobMakerOutputFormatPicker({super.key}) extends StatefulWidget {
  @override
  State<JobMakerOutputFormatPicker> createState() =>
      _JobMakerOutputFormatPickerState();
}

class _JobMakerOutputFormatPickerState extends State<JobMakerOutputFormatPicker>
    with AfterLayoutMixin {
  final ScrollController _scrollController = .new();

  @override
  void initState() {
    super.initState();
    SettingsBox().outputFormatPickerAccessCount++;
    printLog(
      '[AdsSettings] outputFormatPickerAccessCount increased: ${SettingsBox().outputFormatPickerAccessCount}',
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void afterFirstLayout(BuildContext context) {
    final model = context.read<JobMakerViewModel>();
    if (model.selectedFormatEntry != null) {
      return;
    }

    final formatConfigModel = model.formatConfigModel;
    final defaultFormat = formatConfigModel.formats.firstWhereOrNull(
      (e) => e.name == SettingsBox().defaultOutputFormat,
    );
    if (defaultFormat != null) {
      model.setSelectedFormatEntry(defaultFormat);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatConfigModel = context
        .read<JobMakerViewModel>()
        .formatConfigModel;
    final audioFormats = formatConfigModel.formats
        .where((f) => f.outputType == .audio)
        .toList();
    final videoFormats = formatConfigModel.formats
        .where((f) => f.outputType == .video)
        .toList();

    return Column(
      crossAxisAlignment: .start,
      children: [
        Expanded(
          child: Selector<JobMakerViewModel, FormatEntry?>(
            selector: (context, model) => model.selectedFormatEntry,
            builder: (context, selectedFormat, _) {
              return Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: ListView(
                  controller: _scrollController,
                  padding: .symmetric(
                    vertical: Spacing.d16,
                    horizontal: Spacing.d16,
                  ),
                  children: [
                    const OutputFormatAdItem(),
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
                ),
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
      crossAxisAlignment: .start,
      children: [
        SectionTitle(
          label,
          padding: .only(
            bottom: Spacing.d16,
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: .zero,
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
