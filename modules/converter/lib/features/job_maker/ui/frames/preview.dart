import 'package:converter/converter.dart';
import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:platform_utils/platform_utils.dart';

class JobMakerPreview extends StatelessWidget {
  const JobMakerPreview({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<JobMakerViewModel>(
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              context.l10n.outputFolder,
            ),
            Padding(
              padding: EdgeInsets.only(
                top: Spacing.d16,
                left: Spacing.d16,
                right: Spacing.d16,
              ),
              child: Button(
                tooltip: model.outputDirectoryPath,
                variant: ButtonVariant.ghost,
                padding: EdgeInsets.symmetric(
                  horizontal: Spacing.d16,
                  vertical: Spacing.d12,
                ),
                icon: Padding(
                  padding: EdgeInsets.only(right: Spacing.d4),
                  child: ImageView(
                    Assets.hugeicons.stroke.filesFolders.folder01,
                    color: context.theme.primaryColor,
                    size: Spacing.d24,
                  ),
                ),
                label: outputDirectoryName ?? context.l10n.selectFolder,
                labelTextAlign: TextAlign.start,
                expandTitle: true,
                trailingIcon: !isFolderSelected
                    ? null
                    : Text(
                        context.l10n.selectFolder,
                        style: context.theme.textTheme.labelSmall?.copyWith(
                          color: context.theme.colorScheme.primary,
                        ),
                      ),
                mainAxisAlignment: MainAxisAlignment.start,
                onPressed: () {
                  _handleChooseOutputDirectoryPressed(context);
                },
              ),
            ),
            Spacing.v8,
            SectionTitle(
              context.l10n.outputFiles,
            ),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.symmetric(
                  horizontal: Spacing.d16,
                  vertical: Spacing.d16,
                ),
                itemCount: selectedPaths.length,
                separatorBuilder: (_, _) => Spacing.v4,
                itemBuilder: (context, index) {
                  final filePath = selectedPaths.elementAt(index).path;
                  final outputFileName = outputFileNames[filePath] ?? '';
                  final file = File(filePath);
                  return OutputFileItem(
                    file,
                    outputFormat: formatEntry,
                    outputFileName: outputFileName,
                    hasError: errorPaths.contains(filePath),
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
    );
  }

  Future<void> _handleChooseOutputDirectoryPressed(BuildContext context) async {
    final viewModel = context.read<JobMakerViewModel>();
    final currentPath = viewModel.outputDirectoryPath;

    final (path, error) = await FileUtils.chooseSavePath(
      context,
      initialPath: currentPath,
    );

    if (error != null) {
      context.toast(error, type: MessageType.error);
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

    viewModel.setOutputFileName(file.path, newName);
  }
}
