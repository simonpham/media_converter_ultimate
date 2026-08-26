import 'package:converter/converter.dart';
import 'package:flutter/material.dart';
import 'package:icons/icons.dart';
import 'package:platform_utils/platform_utils.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';
import 'package:utils/utils.dart';

class const JobMakerPreview({super.key}) extends StatefulWidget {
  @override
  State<JobMakerPreview> createState() => _JobMakerPreviewState();
}

class _JobMakerPreviewState extends State<JobMakerPreview> {
  final ScrollController _scrollController = .new();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: Consumer<JobMakerViewModel>(
        builder: (context, model, _) {
          final selectedPaths = model.selectedFiles;
          final outputFileNames = model.outputFileNames;
          final formatEntry = model.selectedFormatEntry;
          final outputDirectoryName = switch (model.outputDirectoryPath) {
            String path => basename(path),
            _ => null,
          };
          final isFolderSelected = model.outputDirectoryPath != null;

          if (selectedPaths.isEmpty) {
            return Text(context.l10n.noFilesSelected);
          }

          if (formatEntry == null) {
            return Text(context.l10n.noOutputFormatSelected);
          }

          final errorPaths = model.errorPaths;
          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              const SliverToBoxAdapter(
                child: PreviewPageAdItem(),
              ),
              SliverToBoxAdapter(
                child: Divider(
                  height: Spacing.d16,
                ),
              ),
              PinnedHeaderSliver(
                child: Container(
                  color: context.theme.colorScheme.surface,
                  padding: .only(
                    top: Spacing.d8,
                  ),
                  child: RoundCard(
                    margin: .symmetric(
                      horizontal: Spacing.d16,
                    ),
                    padding: .only(
                      bottom: Spacing.d16,
                    ),
                    child: Column(
                      crossAxisAlignment: .start,
                      mainAxisSize: .min,
                      children: [
                        Container(
                          padding: .only(
                            left: Spacing.d16,
                            right: Spacing.d16,
                            top: Spacing.d4,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: SectionTitle(
                                  context.l10n.outputFolder,
                                  padding: .zero,
                                ),
                              ),
                              CheckBoxListTile(
                                style: .compact,
                                alignment: .left,
                                title: context.l10n.setAsDefault,
                                value: model.shouldRememberOutputFolder,
                                onChanged: (value) {
                                  model.setRememberOutputFolder(value);
                                },
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: .only(
                            left: Spacing.d16,
                            right: Spacing.d16,
                          ),
                          child: Button(
                            tooltip: model.outputDirectoryPath,
                            variant: .ghost,
                            padding: .symmetric(
                              horizontal: Spacing.d16,
                              vertical: Spacing.d12,
                            ),
                            icon: Padding(
                              padding: .only(right: Spacing.d4),
                              child: ImageView(
                                Assets.folder01,
                                color: context.theme.primaryColor,
                                size: Spacing.d24,
                              ),
                            ),
                            label:
                                outputDirectoryName ??
                                context.l10n.selectFolder,
                            labelTextAlign: .start,
                            titleExpand: .expand,
                            trailingIcon: !isFolderSelected
                                ? null
                                : Text(
                                    context.l10n.selectFolder,
                                    style: context.theme.textTheme.labelSmall
                                        ?.copyWith(
                                          color:
                                              context.theme.colorScheme.primary,
                                        ),
                                  ),
                            mainAxisAlignment: .start,
                            onPressed: () {
                              _handleChooseOutputDirectoryPressed(context);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              PinnedHeaderSliver(
                child: ColoredBox(
                  color: context.theme.colorScheme.surface,
                  child: SectionTitle(
                    context.l10n.outputFiles,
                    padding: .only(
                      left: Spacing.d16,
                      right: Spacing.d16,
                      top: Spacing.d16,
                      bottom: Spacing.d8,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: .symmetric(
                  horizontal: Spacing.d16,
                  vertical: Spacing.d8,
                ),
                sliver: SliverList.separated(
                  itemCount: selectedPaths.length,
                  separatorBuilder: (_, _) => Spacing.v8,
                  itemBuilder: (context, index) {
                    final filePath = selectedPaths.elementAt(index).path;
                    final outputFileName = outputFileNames[filePath] ?? '';
                    final file = File(filePath);
                    return OutputFileItem(
                      file,
                      index: index + 1,
                      outputFormat: formatEntry,
                      outputFileName: outputFileName,
                      failure: errorPaths.containsKey(filePath)
                          ? errorPaths[filePath]
                          : null,
                      onRenamePressed: () {
                        _handleRenameOutputFilePressed(context, file);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleChooseOutputDirectoryPressed(BuildContext context) async {
    final viewModel = context.read<JobMakerViewModel>();
    final currentPath = viewModel.outputDirectoryPath;

    final (path, failure) = await injector<FileService>().chooseSavePath(
      context,
      initialPath: currentPath,
    );

    if (failure != null) {
      context.toastFailure(failure);
    }

    if (path == null) {
      return;
    }

    viewModel.setOutputDirectoryPath(path);
  }

  Future<void> _handleRenameOutputFilePressed(
    BuildContext context,
    File file,
  ) async {
    final viewModel = context.read<JobMakerViewModel>();
    final outputFileName = viewModel.outputFileNames[file.path] ?? '';
    final newName = await InputTextDialog.show(
      context,
      initialValue: outputFileName,
      title: context.l10n.outputFileName,
      labelText: context.l10n.fileName,
      hintText: context.l10n.enterNewName,
      cancelText: context.l10n.cancel,
      confirmText: context.l10n.ok,
    );

    if (newName == null) {
      return;
    }

    final trimmedNewName = newName.trim();
    if (!isValidFilename(trimmedNewName)) {
      context.toastError(context.l10n.failureFileNameIsNotValid);
      return;
    }

    viewModel.setOutputFileName(file.path, trimmedNewName);
  }
}
