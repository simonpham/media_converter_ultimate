import 'package:converter/converter.dart';
import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:platform_utils/platform_utils.dart';
import 'package:utils/utils.dart';

class JobManager extends StatefulWidget {
  const JobManager({
    super.key,
  });

  @override
  State<JobManager> createState() => _JobManagerState();
}

class _JobManagerState extends State<JobManager> {
  final MenuController _menuController = MenuController();

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
            ],
            builder: (context, data) {
              final direction = Directionality.of(context);

              final List<ConvertJob> pendingJobs = data[0] ?? [];
              final List<ConvertJob> completedJobs = data[1] ?? [];
              final List<ConvertJob> runningJobs = data[2] ?? [];
              final isAllEmpty =
                  pendingJobs.isEmpty &&
                  completedJobs.isEmpty &&
                  runningJobs.isEmpty;
              return CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: kToolbarHeight * 1.2,
                    collapsedHeight: kToolbarHeight,
                    flexibleSpace: FlexibleSpaceBar(
                      centerTitle: true,
                      title: Text(
                        context.l10n.jobManager,
                      ),
                    ),
                    pinned: true,
                    backgroundColor: context.theme.scaffoldBackgroundColor,
                    actions: [
                      Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: Spacing.d16,
                        ),
                        child: Directionality(
                          textDirection: switch (direction) {
                            TextDirection.ltr => TextDirection.rtl,
                            TextDirection.rtl => TextDirection.ltr,
                          },
                          child: MenuAnchor(
                            controller: _menuController,
                            alignmentOffset: Offset(0, Spacing.d4),
                            menuChildren: [
                              Directionality(
                                textDirection: direction,
                                child: ListItem(
                                  leading: ImageView(
                                    Assets
                                        .hugeicons
                                        .stroke
                                        .addRemoveDelete
                                        .delete01,
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
                              variant: ButtonVariant.ghost,
                              padding: EdgeInsets.all(Spacing.d8),
                              child: ImageView(
                                Assets.hugeicons.stroke.moreMenu.moreVertical,
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
                        return JobItem(
                          job,
                          onRemoveItem: () => _handleRemoveItem(context, job),
                          onOpenLogs: () => _handleOpenLogs(context, job),
                          onStop: () => _handleStop(context, job),
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
                        final isSuccess = job.status == JobStatus.completed;
                        return JobItem(
                          job,
                          onRemoveItem: () => _handleRemoveItem(context, job),
                          onOpenLogs: () => _handleOpenLogs(context, job),
                          onShare: !isSuccess
                              ? null
                              : () => _handleShare(context, job),
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
                          icon: Assets.hugeicons.bulk.smileyEmojis.smile,
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
        mainAxisSize: MainAxisSize.min,
        variant: ButtonVariant.primary,
        icon: ImageView(
          Assets.hugeicons.stroke.addRemoveDelete.add01,
          size: Spacing.d24,
          color: context.theme.colorScheme.onPrimary,
        ),
        label: context.l10n.create,
        onPressed: () {
          _handleCreateJob(context);
        },
      ),
    );
  }

  Future<void> _handleCreateJob(BuildContext context) async {
    final jobs = await JobMaker.cook(context);
    final viewModel = context.read<JobManagerViewModel>();
    await viewModel.addJobs(jobs);
  }

  void _handleOpenLogs(BuildContext context, ConvertJob job) {
    job.openLogs(context);
  }

  Future<void> _handleShare(BuildContext context, ConvertJob job) async {
    final file = job.outputFile;
    await file.share();
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

    if (action != ConfirmAction.negative) {
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

  void _handleStop(BuildContext context, ConvertJob job) {
    context.read<JobManagerViewModel>().removeRunningJob(job);
  }

  void _handleRestart(BuildContext context, ConvertJob job) {
    // TODO: check existing file.
    context.read<JobManagerViewModel>().restartJob(job);
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
}
