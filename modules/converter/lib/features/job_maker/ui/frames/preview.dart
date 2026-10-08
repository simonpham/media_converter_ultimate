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
                child: RoundCard(
                  margin: .symmetric(
                    horizontal: Spacing.d16,
                    vertical: Spacing.d8,
                  ),
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Spacing.v16,
                      Row(
                        children: [
                          Spacing.h16,
                          ImageView(
                            Assets.folder01,
                            size: Spacing.d24,
                            color: context.theme.colorScheme.primary,
                          ),
                          Spacing.h8,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: .start,
                              children: [
                                Text(
                                  context.l10n.outputSaveTo,
                                  style: context.theme.textTheme.labelMedium,
                                ),
                                Text(
                                  outputDestinationLabel(
                                    context,
                                    model.outputDirectoryPath,
                                  ),
                                  style: context.theme.textTheme.bodyLarge,
                                ),
                              ],
                            ),
                          ),
                          Button(
                            variant: .secondary,
                            padding: .symmetric(horizontal: Spacing.d8),
                            child: ImageView(
                              Assets.edit02,
                              size: Spacing.d20,
                              color: context.theme.colorScheme.onSecondary,
                            ),
                            onPressed: () =>
                                _handleChooseOutputDirectoryPressed(context),
                          ),
                          Spacing.h16,
                        ],
                      ),
                      Padding(
                        padding: .symmetric(
                          horizontal: Spacing.d8,
                        ),
                        child: CheckBoxListTile(
                          style: .compact,
                          alignment: .left,
                          title: context.l10n.outputRememberFolder,
                          value: model.shouldRememberOutputFolder,
                          onChanged: model.setRememberOutputFolder,
                        ),
                      ),
                      if (model.outputDirectoryPath ==
                          OutputDestination.appStorage) ...[
                        Spacing.v8,
                        Text(
                          context.l10n.outputAppStorageHint,
                          style: context.theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // The review panel already shows the summary beside the wizard.
              if (!JobMaker.hasReviewPanel(context.screenSize))
                const SliverToBoxAdapter(child: ConversionSummary()),
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
                      trim: model.trimFor(filePath),
                      onTrimPressed: model.isPreparingJobs
                          ? null
                          : () {
                              _handleTrimPressed(context, file);
                            },
                    );
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: Spacing.d12 * 10,
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

    final path = await OutputDestinationPicker.show(
      context,
      initialPath: currentPath,
    );
    if (!context.mounted || path == null) return;

    viewModel.setOutputDirectoryPath(path);
  }

  Future<void> _handleTrimPressed(BuildContext context, File file) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final model = context.read<JobMakerViewModel>();
    final result = await context.navigator.push<FileTrimResult>(
      MaterialPageRoute(
        builder: (context) => TrimEditor(
          path: file.path,
          initial: model.trimFor(file.path),
        ),
      ),
    );
    if (context.mounted && result != null) model.setFileTrim(file.path, result);
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
