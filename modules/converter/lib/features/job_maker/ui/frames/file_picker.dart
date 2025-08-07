import 'package:converter/converter.dart';
import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:platform_utils/platform_utils.dart';

class JobMakerFilePicker extends StatelessWidget {
  const JobMakerFilePicker({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<JobMakerViewModel, Map<String, String?>>(
      selector: (context, model) => model.selectedFiles,
      builder: (context, files, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (files.isNotEmpty) ...[
              Padding(
                padding: EdgeInsets.only(
                  left: Spacing.d16,
                  right: Spacing.d16,
                  top: Spacing.d16,
                ),
                child: Text(
                  context.l10n.selectedFiles(files.length),
                  style: context.theme.textTheme.titleSmall?.copyWith(
                    color: context.theme.primaryColor,
                  ),
                ),
              ),
            ],
            Expanded(
              child: Scrollbar(
                thumbVisibility: true,
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: Spacing.d16,
                        vertical: Spacing.d16,
                      ),
                      sliver: SliverList.separated(
                        itemCount: files.length,
                        separatorBuilder: (_, _) => Spacing.v4,
                        itemBuilder: (context, index) {
                          final filePath = files.keys.elementAt(index);
                          final file = File(filePath);
                          return FileItem(
                            file,
                            onRemove: () {
                              context.read<JobMakerViewModel>().removeFile(
                                file,
                              );
                            },
                          );
                        },
                      ),
                    ),
                    if (files.isEmpty) ...[
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // TODO: add icon.
                              Text(
                                context.l10n.noFilesSelected,
                                style: context.theme.textTheme.titleSmall,
                              ),
                              Text(
                                context.l10n.tapAddFilesToBegin,
                                style: context.theme.textTheme.bodySmall,
                              ),
                            ],
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
