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
        final formatEntry = model.selectedFormatEntry;
        final outputDirectoryName = model.outputDirectoryName;

        if (selectedPaths.isEmpty) {
          return Text('No files selected'.hardcode);
        }

        if (formatEntry == null) {
          return Text('No output format selected'.hardcode);
        }

        final errorPaths = model.errorPaths;
        return Column(
          children: [
            /// Choose output directory.
            Padding(
              padding: EdgeInsets.only(
                left: Spacing.d16,
                right: Spacing.d16,
              ),
              child: Text(
                'Output Directory'.hardcode,
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                top: Spacing.d16,
                left: Spacing.d16,
                right: Spacing.d16,
              ),
              child: Text(
                outputDirectoryName ?? 'No directory selected',
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                top: Spacing.d16,
                left: Spacing.d16,
                right: Spacing.d16,
              ),
              child: Button(
                variant: ButtonVariant.secondary,
                label: 'Choose'.hardcode,
                onPressed: () {
                  _handleChooseOutputDirectoryPressed(context);
                },
              ),
            ),
            const Divider(),

            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.symmetric(
                  horizontal: Spacing.d16,
                  vertical: Spacing.d16,
                ),
                itemCount: selectedPaths.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, index) {
                  final filePath = selectedPaths.keys.elementAt(index);
                  final outputFileName = selectedPaths[filePath];
                  final file = File(filePath);
                  return OutputFileItem(
                    file,
                    outputFormat: formatEntry,
                    outputFileName: outputFileName,
                    hasError: errorPaths.contains(filePath),
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

    final (path, name) = await FileUtils.chooseSavePath(
      context,
      initialPath: currentPath,
    );
    if (path == null) {
      return;
    }

    viewModel.setOutputDirectoryPath(path, name);
  }
}
