import 'package:converter/converter.dart';
import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:platform_utils/platform_utils.dart';

class JobManager extends StatelessWidget {
  const JobManager({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<JobManagerViewModel>(
        builder: (context, model, _) {
          final pendingJobs = model.pendingJobs;
          final completedJobs = model.completedJobs;
          final runningJobs = model.runningJobs;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: kToolbarHeight * 1.2,
                collapsedHeight: kToolbarHeight,
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  title: Text(
                    'Job manager'.hardcode,
                  ),
                ),
                pinned: true,
                backgroundColor: context.theme.scaffoldBackgroundColor,
              ),
              if (runningJobs.isNotEmpty) ...[
                SliverToBoxAdapter(child: Spacing.v16),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: Spacing.d16,
                    ),
                    child: Text(
                      'Running'.hardcode,
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
                      onShare: () => _handleShare(context, job),
                      onOpenFile: () => _handleOpenFile(context, job),
                      onOpenFolder: () => _handleOpenFolder(context, job),
                      onDelete: () => _handleDelete(context, job),
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
                      'Pending'.hardcode,
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
                      onShare: () => _handleShare(context, job),
                      onOpenFile: () => _handleOpenFile(context, job),
                      onOpenFolder: () => _handleOpenFolder(context, job),
                      onDelete: () => _handleDelete(context, job),
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
                      'Finished'.hardcode,
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
                    return JobItem(
                      job,
                      onRemoveItem: () => _handleRemoveItem(context, job),
                      onOpenLogs: () => _handleOpenLogs(context, job),
                      onShare: () => _handleShare(context, job),
                      onOpenFile: () => _handleOpenFile(context, job),
                      onOpenFolder: () => _handleOpenFolder(context, job),
                      onDelete: () => _handleDelete(context, job),
                    );
                  },
                ),
                SliverToBoxAdapter(
                  child: Spacing.vertical(Spacing.d56),
                ),
                const SliverToBoxAdapter(
                  child: BottomSpacer(),
                ),
              ],
            ],
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
        label: 'Create'.hardcode,
        onPressed: () {
          _handleCreateJob(context);
        },
      ),
    );
  }

  Future<void> _handleCreateJob(BuildContext context) async {
    final jobs = await JobMaker.cook(context);
    final viewModel = context.read<JobManagerViewModel>();
    viewModel.addJobs(jobs);
  }

  void _handleRemoveItem(BuildContext context, ConvertJob job) {
    // TODO: Implement.
  }

  void _handleOpenLogs(BuildContext context, ConvertJob job) {
    // TODO: Implement.
  }

  Future<void> _handleShare(BuildContext context, ConvertJob job) async {
    final file = job.outputFile;
    await file.share();
  }

  Future<void> _handleOpenFile(BuildContext context, ConvertJob job) async {
    // TODO: check for iOS.
  }

  Future<void> _handleOpenFolder(BuildContext context, ConvertJob job) async {
    // TODO: check for iOS.
  }

  Future<void> _handleDelete(BuildContext context, ConvertJob job) async {
    // final file = await job.outputFile;
    // if (file == null || !file.isFile) {
    //   return;
    // }
    // final success = await file.delete();
    // if (!success) {
    //   // TODO: Show error.
    //   return;
    // }

    _handleRemoveItem(context, job);
  }
}
