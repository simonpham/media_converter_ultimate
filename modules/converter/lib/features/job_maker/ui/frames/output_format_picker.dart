import 'dart:async';

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
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = .new(
      text: this.context.read<JobMakerViewModel>().formatQuery,
    );
    unawaited(
      SettingsBox().incrementUsageCounter(.outputFormatPickerAccessCount),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
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
      unawaited(model.setSelectedFormatEntry(defaultFormat));
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatConfigModel = context
        .read<JobMakerViewModel>()
        .formatConfigModel;

    return Column(
      crossAxisAlignment: .start,
      children: [
        Expanded(
          child: Consumer<JobMakerViewModel>(
            builder: (context, model, _) {
              final selectedFormat = model.selectedFormatEntry;
              final audioFormats = model.visibleFormats
                  .where(
                    (format) => format.outputType == .audio,
                  )
                  .toList();
              final videoFormats = model.visibleFormats
                  .where(
                    (format) => format.outputType == .video,
                  )
                  .toList();
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
                    InputText(
                      controller: _searchController,
                      hintText: context.l10n.searchFormatsHint,
                      onChanged: model.setFormatQuery,
                      textInputAction: .search,
                      onSubmitted: (_) => FocusScope.of(context).unfocus(),
                    ),
                    Spacing.v16,
                    if (model.formatQuery.trim().isEmpty) ...[
                      const JobMakerPresetSelection(),
                      Spacing.v16,
                    ],
                    if (model.visibleFormats.isEmpty)
                      Text(context.l10n.noMatchingFormats),
                    if (videoFormats.isNotEmpty)
                      _buildGridCategory(
                        context,
                        context.l10n.video,
                        formatConfigModel,
                        videoFormats,
                        selectedFormat,
                      ),
                    if (videoFormats.isNotEmpty && audioFormats.isNotEmpty)
                      Spacing.v16,
                    if (audioFormats.isNotEmpty)
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
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: Spacing.d96,
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
                unawaited(
                  context.read<JobMakerViewModel>().setSelectedFormatEntry(
                    format,
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
