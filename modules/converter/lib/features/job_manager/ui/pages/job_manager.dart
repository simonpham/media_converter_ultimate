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
  final ScrollController _scrollController = .new();
  final ScrollController _sidebarScrollController = .new();
  final ScrollController _jobsScrollController = .new();
  bool _isCreatingJob = false;

  @override
  void dispose() {
    _scrollController.dispose();
    _sidebarScrollController.dispose();
    _jobsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = context.screenSize;
    final columns = switch (screenSize) {
      .small || .large => 1,
      .normal || .larger => 2,
      .extraLarge => 3,
    };
    return Scaffold(
      appBar: switch (screenSize) {
        .small || .normal => null,
        .large || .larger || .extraLarge => AppBar(
          centerTitle: true,
          title: Text(
            context.l10n.jobManager,
            maxLines: 1,
            overflow: .ellipsis,
          ),
          backgroundColor: context.theme.scaffoldBackgroundColor,
          actions: [_buildMenu(context)],
        ),
      },
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
              final List<ConvertJob> pendingJobs = data[0] ?? [];
              final List<ConvertJob> completedJobs = data[1] ?? [];
              final List<ConvertJob> runningJobs = data[2] ?? [];
              final List<ConvertJob> actionRequiredJobs = data[3] ?? [];
              final isAllEmpty =
                  pendingJobs.isEmpty &&
                  completedJobs.isEmpty &&
                  runningJobs.isEmpty &&
                  actionRequiredJobs.isEmpty;
              final jobSlivers = [
                ..._buildJobSection(
                  context,
                  title: context.l10n.actionRequired,
                  jobs: actionRequiredJobs,
                  columns: columns,
                  itemBuilder: (job, margin) => JobItem(
                    job,
                    margin: margin,
                    onOpenLogs: () => _handleOpenLogs(context, job),
                    onRemoveItem: () =>
                        unawaited(_handleRemoveItem(context, job)),
                    onRetryExport: () => unawaited(
                      _handleRetryExport(context, job),
                    ),
                    onRenameOutputFile: () => unawaited(
                      _handleRenameOutputFile(context, job),
                    ),
                    onSelectNewOutputPath: () => unawaited(
                      _handleSelectNewOutputPath(context, job),
                    ),
                  ),
                ),
                ..._buildJobSection(
                  context,
                  title: context.l10n.running,
                  jobs: runningJobs,
                  columns: columns,
                  itemBuilder: (job, margin) {
                    final executionId = model.activeExecutionId(job.id);
                    return JobItem(
                      job,
                      margin: margin,
                      onRemoveItem: () =>
                          unawaited(_handleRemoveItem(context, job)),
                      onOpenLogs: () => _handleOpenLogs(context, job),
                      onStop:
                          job.status == .stopping ||
                              job.status == .cleaning ||
                              (job.sessionId == null && executionId == null)
                          ? null
                          : () => unawaited(
                              _handleStop(context, job, executionId),
                            ),
                    );
                  },
                ),
                ..._buildJobSection(
                  context,
                  title: context.l10n.pending,
                  jobs: pendingJobs,
                  columns: columns,
                  itemBuilder: (job, margin) => JobItem(
                    job,
                    margin: margin,
                    onRemoveItem: () =>
                        unawaited(_handleRemoveItem(context, job)),
                    onOpenLogs: () => _handleOpenLogs(context, job),
                  ),
                ),
                ..._buildJobSection(
                  context,
                  title: context.l10n.finished,
                  jobs: completedJobs,
                  columns: columns,
                  itemBuilder: (job, margin) {
                    final isSuccess = job.status == .completed;
                    return JobItem(
                      job,
                      margin: margin,
                      onRemoveItem: () =>
                          unawaited(_handleRemoveItem(context, job)),
                      onOpenLogs: () => _handleOpenLogs(context, job),
                      onShare: !isSuccess
                          ? null
                          : () => unawaited(_handleShare(context, job)),
                      onOpenFile: isSuccess
                          ? () => unawaited(_handleOpenFile(context, job))
                          : null,
                      onDelete: !isSuccess
                          ? null
                          : () => unawaited(_handleDelete(context, job)),
                      onRestart: isSuccess
                          ? null
                          : () => unawaited(_handleRestart(context, job)),
                    );
                  },
                ),
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
              ];
              return switch (screenSize) {
                .small || .normal => Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: CustomScrollView(
                    controller: _scrollController,
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
                        actions: [_buildMenu(context)],
                      ),
                      const SliverToBoxAdapter(
                        key: ValueKey('job_manager_ad_item'),
                        child: JobAdItem(),
                      ),
                      SliverToBoxAdapter(
                        child: _buildPresetShortcuts(context),
                      ),
                      ...jobSlivers,
                    ],
                  ),
                ),
                .large || .larger || .extraLarge => Row(
                  crossAxisAlignment: .stretch,
                  children: [
                    SizedBox(
                      width: Spacing.d360,
                      child: Scrollbar(
                        controller: _sidebarScrollController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _sidebarScrollController,
                          child: Column(
                            crossAxisAlignment: .stretch,
                            children: [
                              _buildPresetShortcuts(context),
                              const JobAdItem(
                                key: ValueKey('job_manager_ad_item'),
                              ),
                              const BottomSpacer(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    VerticalDivider(width: Spacing.d1),
                    Expanded(
                      child: Scrollbar(
                        controller: _jobsScrollController,
                        thumbVisibility: true,
                        child: CustomScrollView(
                          controller: _jobsScrollController,
                          slivers: jobSlivers,
                        ),
                      ),
                    ),
                  ],
                ),
              };
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
          unawaited(_handleCreateJob(context));
        },
      ),
    );
  }

  Widget _buildPresetShortcuts(BuildContext context) => HomePresetShortcuts(
    enabled: !_isCreatingJob,
    onSelected: (preset) => unawaited(
      _handleCreateJob(context, initialPreset: preset),
    ),
  );

  Widget _buildMenu(BuildContext context) {
    final direction = Directionality.of(context);
    return Container(
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
                  unawaited(
                    _handleClearFinishedJobs(context),
                  );
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
    );
  }

  /// Builds a titled job section. With more than one column, jobs are laid
  /// out in rows so cards keep their natural height.
  List<Widget> _buildJobSection(
    BuildContext context, {
    required String title,
    required List<ConvertJob> jobs,
    required int columns,
    required Widget Function(ConvertJob job, EdgeInsetsGeometry? margin)
    itemBuilder,
  }) {
    if (jobs.isEmpty) return const [];
    final rowCount = (jobs.length / columns).ceil();
    return [
      SliverToBoxAdapter(child: Spacing.v16),
      SliverToBoxAdapter(
        child: Padding(
          padding: .symmetric(
            horizontal: Spacing.d16,
          ),
          child: Text(
            title,
            style: context.theme.textTheme.labelLarge?.copyWith(
              color: context.theme.colorScheme.primary,
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(child: Spacing.v8),
      if (columns == 1)
        SliverList.separated(
          itemCount: jobs.length,
          separatorBuilder: (_, _) => Spacing.v8,
          itemBuilder: (context, index) => itemBuilder(jobs[index], null),
        )
      else
        SliverList.separated(
          itemCount: rowCount,
          separatorBuilder: (_, _) => Spacing.v8,
          itemBuilder: (context, row) => Padding(
            padding: .symmetric(
              horizontal: Spacing.d16,
            ),
            child: Row(
              crossAxisAlignment: .start,
              spacing: Spacing.d8,
              children: [
                for (var column = 0; column < columns; column++)
                  Expanded(
                    child: switch (row * columns + column) {
                      final index when index < jobs.length => itemBuilder(
                        jobs[index],
                        .zero,
                      ),
                      _ => const SizedBox.shrink(),
                    },
                  ),
              ],
            ),
          ),
        ),
    ];
  }

  Future<void> _handleCreateJob(
    BuildContext context, {
    ConversionPreset? initialPreset,
  }) async {
    if (_isCreatingJob) return;
    setState(() => _isCreatingJob = true);
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (!context.mounted) return;
      final sdkInt = androidInfo.version.sdkInt;
      // Android 11+ uses picker URI grants and app-owned MediaStore outputs.
      // Keep the gate for Android 10's existing legacy-storage mode and older.
      if (sdkInt < 30) {
        final status = await Permission.storage.request();
        if (!context.mounted) return;
        if (!status.isGranted) {
          await _handlePermissionDenied(context);
          return;
        }
      }

      final viewModel = context.read<JobManagerViewModel>();
      await JobMaker.cook(
        context,
        initialPreset: initialPreset,
        onSubmitJobs: viewModel.enqueueJobs,
      );
    } catch (error, trace) {
      printError(error, trace);
      if (context.mounted) {
        context.toastFailure(
          error is Failure ? error : Failure(error.toString()),
        );
      }
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
      final exists = await files.isFileExist(job.outputLocation);
      if (!context.mounted) return;
      if (!exists) {
        context.toastError(context.l10n.outputFileUnavailable);
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
      final exists = await files.isFileExist(job.outputLocation);
      if (!context.mounted) return;
      if (!exists) {
        context.toastError(context.l10n.outputFileUnavailable);
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

    try {
      final failure = await context.read<JobManagerViewModel>().removeJob(job);
      if (failure != null && context.mounted) context.toastFailure(failure);
    } catch (error, trace) {
      printError(error, trace);
      if (context.mounted) {
        context.toastFailure(
          error is Failure ? error : Failure(error.toString()),
        );
      }
    }
  }

  Future<void> _runJobAction(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error, trace) {
      printError(error, trace);
      if (context.mounted) {
        context.toastFailure(
          error is Failure ? error : Failure(error.toString()),
        );
      }
    }
  }

  Future<void> _handleDelete(
    BuildContext context,
    ConvertJob job,
  ) => _runJobAction(context, () async {
    if (job.status.isProcessing) return;
    final action = await ConfirmDialog.show(
      context,
      title: context.l10n.deleteFileConfirmationTitle,
      message: context.l10n.deleteFileConfirmationMessage,
      negativeText: context.l10n.delete,
      positiveText: context.l10n.cancel,
    );
    if (!context.mounted || action != .negative) return;

    final model = context.read<JobManagerViewModel>();
    final failure = await model.deleteOutputFile(job);
    if (failure != null) {
      if (context.mounted) context.toastFailure(failure);
      return;
    }
    if (context.mounted) {
      context.toastSuccess(
        context.l10n.outputFileHasBeenDeleted(job.outputFileName),
      );
    }
    // Confirmation accepted both output deletion and history cleanup. Finish
    // with the captured app owner even if Home closes during deletion.
    final removalFailure = await model.removeJob(job);
    if (context.mounted && removalFailure != null) {
      context.toastFailure(removalFailure);
    }
  });

  Future<void> _handleStop(
    BuildContext context,
    ConvertJob job,
    String? executionId,
  ) => _runJobAction(
    context,
    () => context.read<JobManagerViewModel>().removeRunningJob(
      job,
      executionId: executionId,
    ),
  );

  Future<void> _handleRetryExport(BuildContext context, ConvertJob job) =>
      _runJobAction(context, () async {
        final failure = await context.read<JobManagerViewModel>().retryExport(
          job,
        );
        if (context.mounted && failure != null) context.toastFailure(failure);
      });

  Future<void> _handleRestart(BuildContext context, ConvertJob job) async {
    try {
      final model = context.read<JobManagerViewModel>();
      final isOutputFileExists = await model.isOutputFileExists(job);
      if (!context.mounted) return;
      if (isOutputFileExists) {
        final confirmOverwrite = await ConfirmDialog.show(
          context,
          title: context.l10n.outputFileExists,
          message: context.l10n.outputFileExistsConfirmationMessage,
          negativeText: context.l10n.cancel,
          positiveText: context.l10n.overwrite,
        );
        if (!context.mounted || confirmOverwrite != .positive) return;
        final failure = await model.deleteOutputFile(job);
        if (!context.mounted) return;
        if (failure != null) {
          context.toastFailure(failure);
          return;
        }
      }
      await model.restartJob(job);
    } catch (error, trace) {
      printError(error, trace);
      if (context.mounted) {
        context.toastFailure(
          error is Failure ? error : Failure(error.toString()),
        );
      }
    }
  }

  Future<void> _handleClearFinishedJobs(BuildContext context) =>
      _runJobAction(context, () async {
        final result = await RadioOptionsDialog.show<ClearFinishedJobsOption>(
          context,
          title: context.l10n.clearHistory,
          message: context.l10n.clearConversionHistoryConfirmationMessage(
            context.theme.colorScheme.error.toWebHex(),
          ),
          useHtmlMessage: true,
          cancelText: context.l10n.cancel,
          confirmText: context.l10n.clearHistory,
          initialValue: .everything,
          values: ClearFinishedJobsOption.values,
          itemLabelBuilder: (option) => option.getLabel(context),
        );
        if (!context.mounted || result == null) return;
        final failure = await context
            .read<JobManagerViewModel>()
            .clearFinishedJobs(result);
        if (!context.mounted) return;
        if (failure != null) {
          context.toastFailure(failure);
          return;
        }
        context.toastSuccess(result.getSuccessMessage(context));
      });

  Future<void> _handleRenameOutputFile(BuildContext context, ConvertJob job) =>
      _runJobAction(context, () async {
        final newName = await InputTextDialog.show(
          context,
          initialValue: job.outputFileName,
          title: context.l10n.outputFileName,
          labelText: context.l10n.fileName,
          hintText: context.l10n.enterNewName,
          cancelText: context.l10n.cancel,
          confirmText: context.l10n.ok,
        );
        if (!context.mounted || newName == null) return;
        final trimmedNewName = newName.trim();
        if (!isValidFilename(trimmedNewName)) {
          context.toastError(context.l10n.failureFileNameIsNotValid);
          return;
        }
        final failure = await context
            .read<JobManagerViewModel>()
            .handleJobRenameAction(job, trimmedNewName);
        if (!context.mounted) return;
        if (failure != null) {
          context.toastFailure(failure);
          return;
        }
        context.toastSuccess(
          context.l10n.outputFileNameHasBeenChanged(trimmedNewName),
        );
      });

  Future<void> _handleSelectNewOutputPath(
    BuildContext context,
    ConvertJob job,
  ) => _runJobAction(context, () async {
    final path = await OutputDestinationPicker.show(
      context,
      initialPath: job.outputDirectoryPath,
    );
    if (!context.mounted || path == null) return;
    final failure = await context
        .read<JobManagerViewModel>()
        .handleJobChooseAnotherPathAction(job, path);
    if (!context.mounted) return;
    if (failure != null) {
      context.toastFailure(failure);
      return;
    }
    context.toastSuccess(
      context.l10n.outputFolderHasBeenChanged(
        outputDestinationLabel(context, path),
      ),
    );
  });

  Future<void> _handlePermissionDenied(BuildContext context) async {
    final action = await ConfirmDialog.show(
      context,
      title: context.l10n.permissionDenied(context.l10n.storage),
      message: context.l10n.permissionDeniedMessage(context.l10n.storage),
      negativeText: context.l10n.goBack,
      positiveText: context.l10n.openSettings,
    );

    if (!context.mounted || action != .positive) {
      return;
    }

    await openAppSettings();
  }
}
