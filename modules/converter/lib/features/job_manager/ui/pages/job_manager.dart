import 'dart:async';

import 'package:converter/converter.dart';
import 'package:flutter/material.dart';
import 'package:icons/icons.dart';
import 'package:platform_utils/platform_utils.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';
import 'package:utils/utils.dart';

class const JobManager({
  super.key,
}) extends StatefulWidget {
  @override
  State<JobManager> createState() => _JobManagerState();
}

class _JobManagerState extends State<JobManager> {
  final MenuController _menuController = .new();
  bool _isCreatingJob = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<JobManagerViewModel>(
        builder: (context, model, _) {
          return MultiStreamBuilder<List<ConvertJob>>(
            streams: [
              model.pendingJobsStream,
              model.completedJobsStream,
              model.runningJobsStream,
              model.actionRequiredJobsStream,
            ],
            builder: (context, data) {
              final direction = Directionality.of(context);

              final List<ConvertJob> pendingJobs = data[0] ?? [];
              final List<ConvertJob> completedJobs = data[1] ?? [];
              final List<ConvertJob> runningJobs = data[2] ?? [];
              final List<ConvertJob> actionRequiredJobs = data[3] ?? [];
              final isAllEmpty =
                  pendingJobs.isEmpty &&
                  completedJobs.isEmpty &&
                  runningJobs.isEmpty &&
                  actionRequiredJobs.isEmpty;
              return CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: kToolbarHeight * 1.2,
                    collapsedHeight: kToolbarHeight,
                    centerTitle: true,
                    title: Text(
                      context.l10n.jobManager,
                      maxLines: 1,
                      overflow: .ellipsis,
                    ),
                    pinned: true,
                    backgroundColor: context.theme.scaffoldBackgroundColor,
                    actions: [
                      Container(
                        margin: .symmetric(
                          horizontal: Spacing.d16,
                        ),
                        child: Directionality(
                          textDirection: switch (direction) {
                            TextDirection.ltr => TextDirection.rtl,
                            TextDirection.rtl => TextDirection.ltr,
                          },
                          child: MenuAnchor(
                            controller: _menuController,
                            alignmentOffset: .new(0, Spacing.d4),
                            menuChildren: [
                              Directionality(
                                textDirection: direction,
                                child: ListItem(
                                  leading: ImageView(
                                    Assets.setting01,
                                    size: Spacing.d24,
                                    color: context.theme.colorScheme.onSurface,
                                  ),
                                  title: context.l10n.settingsTitle,
                                  onTap: () {
                                    _menuController.close();
                                    SettingsPage.go(context);
                                  },
                                ),
                              ),
                              const Divider(),
                              Directionality(
                                textDirection: direction,
                                child: ListItem(
                                  leading: ImageView(
                                    Assets.delete01,
                                    size: Spacing.d24,
                                    color: context.theme.colorScheme.onSurface,
                                  ),
                                  title: context.l10n.clearConversionHistory,
                                  onTap: () {
                                    _menuController.close();
                                    _handleClearFinishedJobs(context);
                                  },
                                ),
                              ),
                            ],
                            builder: (context, controller, _) => Button(
                              variant: .ghost,
                              padding: .all(Spacing.d8),
                              child: ImageView(
                                Assets.moreVertical,
                                size: Spacing.d24,
                                color: context.theme.colorScheme.onSurface,
                              ),
                              onPressed: () {
                                if (controller.isOpen) {
                                  controller.close();
                                  return;
                                }

                                controller.open();
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SliverToBoxAdapter(
                    key: ValueKey('job_manager_ad_item'),
                    child: JobAdItem(),
                  ),
                  SliverToBoxAdapter(
                    child: HomePresetShortcuts(
                      enabled: !_isCreatingJob,
                      onSelected: (preset) => unawaited(
                        _handleCreateJob(context, initialPreset: preset),
                      ),
                    ),
                  ),
                  if (actionRequiredJobs.isNotEmpty) ...[
                    SliverToBoxAdapter(child: Spacing.v16),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: Spacing.d16,
                        ),
                        child: Text(
                          context.l10n.actionRequired,
                          style: context.theme.textTheme.labelLarge?.copyWith(
                            color: context.theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(child: Spacing.v8),
                    SliverList.separated(
                      itemCount: actionRequiredJobs.length,
                      separatorBuilder: (_, _) => Spacing.v8,
                      itemBuilder: (BuildContext context, int index) {
                        final job = actionRequiredJobs[index];
                        return JobItem(
                          job,
                          onOpenLogs: () => _handleOpenLogs(context, job),
                          onRemoveItem: () => _handleRemoveItem(context, job),
                          onRetryExport: () async {
                            final failure = await model.retryExport(job);
                            if (context.mounted && failure != null) {
                              context.toastFailure(failure);
                            }
                          },
                          onRenameOutputFile: () =>
                              _handleRenameOutputFile(context, job),
                          onSelectNewOutputPath: () =>
                              _handleSelectNewOutputPath(context, job),
                        );
                      },
                    ),
                  ],
                  if (runningJobs.isNotEmpty) ...[
                    SliverToBoxAdapter(child: Spacing.v16),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: Spacing.d16,
                        ),
                        child: Text(
                          context.l10n.running,
                          style: context.theme.textTheme.labelLarge?.copyWith(
                            color: context.theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(child: Spacing.v8),
                    SliverList.separated(
                      itemCount: runningJobs.length,
                      separatorBuilder: (_, _) => Spacing.v8,
                      itemBuilder: (BuildContext context, int index) {
                        final job = runningJobs[index];
                        final executionId = model.activeExecutionId(job.id);
                        return JobItem(
                          job,
                          onRemoveItem: () => _handleRemoveItem(context, job),
                          onOpenLogs: () => _handleOpenLogs(context, job),
                          onStop:
                              job.status == .stopping ||
                                  job.status == .cleaning ||
                                  (job.sessionId == null && executionId == null)
                              ? null
                              : () => _handleStop(context, job, executionId),
                        );
                      },
                    ),
                  ],
                  if (pendingJobs.isNotEmpty) ...[
                    SliverToBoxAdapter(child: Spacing.v16),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: Spacing.d16,
                        ),
                        child: Text(
                          context.l10n.pending,
                          style: context.theme.textTheme.labelLarge?.copyWith(
                            color: context.theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(child: Spacing.v8),
                    SliverList.separated(
                      itemCount: pendingJobs.length,
                      separatorBuilder: (_, _) => Spacing.v8,
                      itemBuilder: (BuildContext context, int index) {
                        final job = pendingJobs[index];
                        return JobItem(
                          job,
                          onRemoveItem: () => _handleRemoveItem(context, job),
                          onOpenLogs: () => _handleOpenLogs(context, job),
                        );
                      },
                    ),
                  ],
                  if (completedJobs.isNotEmpty) ...[
                    SliverToBoxAdapter(child: Spacing.v16),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: Spacing.d16,
                        ),
                        child: Text(
                          context.l10n.finished,
                          style: context.theme.textTheme.labelLarge?.copyWith(
                            color: context.theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(child: Spacing.v8),
                    SliverList.separated(
                      itemCount: completedJobs.length,
                      separatorBuilder: (_, _) => Spacing.v8,
                      itemBuilder: (BuildContext context, int index) {
                        final job = completedJobs[index];
                        final isSuccess = job.status == .completed;
                        return JobItem(
                          job,
                          onRemoveItem: () => _handleRemoveItem(context, job),
                          onOpenLogs: () => _handleOpenLogs(context, job),
                          onShare: !isSuccess
                              ? null
                              : () => _handleShare(context, job),
                          onOpenFile: isSuccess
                              ? () => _handleOpenFile(context, job)
                              : null,
                          onDelete: !isSuccess
                              ? null
                              : () => _handleDelete(context, job),
                          onRestart: isSuccess
                              ? null
                              : () => _handleRestart(context, job),
                        );
                      },
                    ),
                  ],
                  if (!isAllEmpty) ...[
                    SliverToBoxAdapter(
                      child: Spacing.vertical(Spacing.d56),
                    ),
                    const SliverToBoxAdapter(
                      child: BottomSpacer(),
                    ),
                  ],
                  if (isAllEmpty) ...[
                    SliverFillRemaining(
                      child: Center(
                        child: EmptyWidget(
                          icon: Assets.smileBulk,
                          title: context.l10n.thereIsNothingHere,
                          subtitle: context.l10n.tapCreateToBegin,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: Button(
        mainAxisSize: .min,
        titleExpand: .shrink,
        variant: .primary,
        icon: ImageView(
          Assets.add01,
          size: Spacing.d24,
          color: context.theme.colorScheme.onPrimary,
        ),
        label: context.l10n.create,
        enable: !_isCreatingJob,
        onPressed: () {
          _handleCreateJob(context);
        },
      ),
    );
  }

  Future<void> _handleCreateJob(
    BuildContext context, {
    ConversionPreset? initialPreset,
  }) async {
    if (_isCreatingJob) return;
    setState(() => _isCreatingJob = true);
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      if (sdkInt < 33) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          await _handlePermissionDenied(context);
          return;
        }
      }

      try {
        final defaultOutputPath =
            await JobMakerPathUtils.getDefaultOutputDirectoryPath();
        if (defaultOutputPath == null) {
          throw Exception('Failed to get default output directory path.');
        }
      } catch (_) {
        context.toastError(
          context.l10n.failureDirectoryNotWritable,
        );
      }

      if (!context.mounted) return;
      final jobs = await JobMaker.cook(context, initialPreset: initialPreset);
      if (!context.mounted) return;
      final viewModel = context.read<JobManagerViewModel>();
      await viewModel.addJobs(jobs);
    } finally {
      if (mounted) setState(() => _isCreatingJob = false);
    }
  }

  void _handleOpenLogs(BuildContext context, ConvertJob job) {
    job.openLogs(context);
  }

  Future<void> _handleShare(BuildContext context, ConvertJob job) async {
    try {
      final files = injector<FileService>();
      if (!await files.isFileExist(job.outputLocation)) {
        if (context.mounted) {
          context.toastError(context.l10n.outputFileUnavailable);
        }
        return;
      }
      await files.shareOutput(job.outputLocation);
    } catch (error, trace) {
      printError(error, trace);
      if (context.mounted) context.toastError(context.l10n.outputShareFailed);
    }
  }

  Future<void> _handleOpenFile(BuildContext context, ConvertJob job) async {
    try {
      final files = injector<FileService>();
      if (!await files.isFileExist(job.outputLocation)) {
        if (context.mounted) {
          context.toastError(context.l10n.outputFileUnavailable);
        }
        return;
      }
      await files.openOutput(job.outputLocation);
    } catch (error, trace) {
      printError(error, trace);
      if (context.mounted) context.toastError(context.l10n.outputOpenFailed);
    }
  }

  Future<void> _handleRemoveItem(BuildContext context, ConvertJob job) async {
    if (job.status.isProcessing) {
      return;
    }

    final failure = await context.read<JobManagerViewModel>().removeJob(job);
    if (failure != null) {
      context.toastFailure(failure);
      return;
    }
  }

  Future<void> _handleDelete(BuildContext context, ConvertJob job) async {
    if (job.status.isProcessing) {
      return;
    }

    final action = await ConfirmDialog.show(
      context,
      title: context.l10n.deleteFileConfirmationTitle,
      message: context.l10n.deleteFileConfirmationMessage,
      negativeText: context.l10n.delete,
      positiveText: context.l10n.cancel,
    );

    if (action != .negative) {
      return;
    }

    final fileName = job.outputFileName;
    final failure = await context.read<JobManagerViewModel>().deleteOutputFile(
      job,
    );
    if (failure != null) {
      context.toastFailure(failure);
      return;
    }

    context.toastSuccess(context.l10n.outputFileHasBeenDeleted(fileName));

    await _handleRemoveItem(context, job);
  }

  void _handleStop(
    BuildContext context,
    ConvertJob job,
    String? executionId,
  ) {
    unawaited(
      context.read<JobManagerViewModel>().removeRunningJob(
        job,
        executionId: executionId,
      ),
    );
  }

  Future<void> _handleRestart(BuildContext context, ConvertJob job) async {
    final model = context.read<JobManagerViewModel>();
    final isOutputFileExists = await model.isOutputFileExists(job);
    if (isOutputFileExists) {
      final confirmOverwrite = await ConfirmDialog.show(
        context,
        title: context.l10n.outputFileExists,
        message: context.l10n.outputFileExistsConfirmationMessage,
        negativeText: context.l10n.cancel,
        positiveText: context.l10n.overwrite,
      );
      if (confirmOverwrite != .positive) {
        return;
      }
      await model.deleteOutputFile(job);
    }

    await model.restartJob(job);
  }

  Future<void> _handleClearFinishedJobs(BuildContext context) async {
    final result = await RadioOptionsDialog.show<ClearFinishedJobsOption>(
      context,
      title: context.l10n.clearHistory,
      message: context.l10n.clearConversionHistoryConfirmationMessage(
        Colors.orange.toWebHex(),
      ),
      useHtmlMessage: true,
      cancelText: context.l10n.cancel,
      confirmText: context.l10n.clearHistory,
      initialValue: .everything,
      values: ClearFinishedJobsOption.values,
      itemLabelBuilder: (option) {
        return option.getLabel(context);
      },
    );

    if (result == null) {
      return;
    }

    final failure = await context.read<JobManagerViewModel>().clearFinishedJobs(
      result,
    );
    if (failure != null) {
      context.toastFailure(failure);
      return;
    }

    context.toastSuccess(
      result.getSuccessMessage(context),
    );
  }

  Future<void> _handleRenameOutputFile(
    BuildContext context,
    ConvertJob job,
  ) async {
    final outputFileName = job.outputFileName;
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

    final model = context.read<JobManagerViewModel>();
    final failure = await model.handleJobRenameAction(job, trimmedNewName);
    if (failure != null) {
      context.toastFailure(failure);
      return;
    }

    context.toastSuccess(
      context.l10n.outputFileNameHasBeenChanged(trimmedNewName),
    );
  }

  Future<void> _handleSelectNewOutputPath(
    BuildContext context,
    ConvertJob job,
  ) async {
    final currentPath = job.outputDirectoryPath;

    final path = await OutputDestinationPicker.show(
      context,
      initialPath: currentPath,
    );
    if (!context.mounted || path == null) return;
    final model = context.read<JobManagerViewModel>();
    final failure = await model.handleJobChooseAnotherPathAction(job, path);
    if (failure != null) {
      context.toastFailure(failure);
      return;
    }

    context.toastSuccess(
      context.l10n.outputFolderHasBeenChanged(
        outputDestinationLabel(context, path),
      ),
    );
  }

  Future<void> _handlePermissionDenied(BuildContext context) async {
    final action = await ConfirmDialog.show(
      context,
      title: context.l10n.permissionDenied(context.l10n.storage),
      message: context.l10n.permissionDeniedMessage(context.l10n.storage),
      negativeText: context.l10n.goBack,
      positiveText: context.l10n.openSettings,
    );

    if (action != ConfirmAction.positive) {
      return;
    }

    await openAppSettings();
  }
}
