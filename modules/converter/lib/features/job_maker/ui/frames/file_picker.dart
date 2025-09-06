import 'package:converter/converter.dart';
import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:icons/icons.dart';
import 'package:platform_utils/platform_utils.dart';

class JobMakerFilePicker extends StatefulWidget {
  const JobMakerFilePicker({
    super.key,
  });

  @override
  State<JobMakerFilePicker> createState() => _JobMakerFilePickerState();
}

class _JobMakerFilePickerState extends State<JobMakerFilePicker> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    SettingsBox().filePickerAccessCount++;
    printLog(
      '[AdsSettings] filePickerAccessCount increased: ${SettingsBox().filePickerAccessCount}',
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Selector<JobMakerViewModel, List<File>>(
      selector: (context, model) => model.selectedFiles,
      builder: (context, files, _) {
        return Column(
          children: [
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    const SliverToBoxAdapter(
                      child: FileAdItem(),
                    ),
                    if (files.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Spacing.v8,
                      ),
                      PinnedHeaderSliver(
                        child: ColoredBox(
                          color: context.theme.colorScheme.surface,
                          child: SectionTitle(
                            context.l10n.selectedFiles(files.length),
                            padding: EdgeInsets.only(
                              left: Spacing.d16,
                              right: Spacing.d16,
                              top: Spacing.d8,
                              bottom: Spacing.d8,
                            ),
                          ),
                        ),
                      ),
                    ],
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: Spacing.d16,
                      ),
                      sliver: ReorderableSliverList(
                        controller: _scrollController,
                        buildDraggableFeedback: (context, constraints, child) {
                          return ConstrainedBox(
                            constraints: constraints,
                            child: child,
                          );
                        },
                        delegate: ReorderableSliverChildBuilderDelegate(
                          (context, index) {
                            final file = files.elementAt(index);
                            return Padding(
                              key: ValueKey(file.path),
                              padding: EdgeInsets.symmetric(
                                vertical: Spacing.d4,
                              ),
                              child: FileItem(
                                file,
                                leading: ImageView(
                                  Assets.verticalDragDrop,
                                  size: Spacing.d20,
                                  color: context.theme.colorScheme.onSurface,
                                ),
                                onRemove: () {
                                  context.read<JobMakerViewModel>().removeFile(
                                    file,
                                  );
                                },
                              ),
                            );
                          },
                          childCount: files.length,
                        ),
                        onReorder: (int oldIndex, int newIndex) {
                          context.read<JobMakerViewModel>().reorderFile(
                            oldIndex,
                            newIndex,
                          );
                        },
                      ),
                    ),
                    if (files.isEmpty) ...[
                      SliverFillRemaining(
                        child: Center(
                          child: EmptyWidget(
                            icon: Assets.fileAddBulk,
                            title: context.l10n.noFilesSelected,
                            subtitle: context.l10n.tapAddFilesToBegin,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                left: Spacing.d16,
                right: Spacing.d16,
                top: Spacing.d16,
              ),
              child: Button(
                variant: ButtonVariant.secondary,
                label: context.l10n.addFiles,
                onPressed: () {
                  _handleChooseFilesPressed(context);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleChooseFilesPressed(BuildContext context) async {
    final files = await FileUtils.chooseFiles(context);
    if (files.isEmpty) {
      return;
    }

    final viewModel = context.read<JobMakerViewModel>();
    viewModel.addFiles(files);
  }
}
