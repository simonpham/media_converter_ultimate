import 'dart:async';

import 'package:converter/converter.dart';
import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

class JobMaker extends StatefulWidget {
  static const String routeName = 'job-maker';
  static const String routePath = routeName;

  final FormatConfigModel formatConfigModel;
  final Map<String, String?> translations;

  static Future<List<ConvertJob>> cook(BuildContext context) async {
    final formatConfigModel = await FormatConfigModel.get(context);
    if (formatConfigModel == null) {
      return const [];
    }

    final Map<String, String?> translations = await ConfigTranslations.get(
      context,
    );

    SettingsBox().lastOutputDirectoryPath ??=
        await JobMakerPathUtils.getDefaultOutputDirectoryPath();

    final result = await context.router.pushNamed(
      routeName,
      extra: (formatConfigModel, translations),
    );
    if (result is! List<ConvertJob> || result.isEmpty) {
      return const [];
    }

    return result;
  }

  static JobMaker fromRouterState(GoRouterState state) {
    final (formatConfigModel, translations) =
        state.extra as (FormatConfigModel, Map<String, String?>);
    return JobMaker(
      formatConfigModel: formatConfigModel,
      translations: translations,
    );
  }

  const JobMaker({
    super.key,
    required this.formatConfigModel,
    required this.translations,
  });

  @override
  State<JobMaker> createState() => _JobMakerState();
}

class _JobMakerState extends State<JobMaker> {
  late final JobMakerViewModel _viewModel = JobMakerViewModel(
    formatConfigModel: widget.formatConfigModel,
    translations: widget.translations,
  );

  final PageController _pageController = PageController();
  final ValueNotifier<int> _currentStepNotifier = ValueNotifier(0);

  @override
  void dispose() {
    _viewModel.dispose();
    _currentStepNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) {
        if (didPop) {
          return;
        }

        _handleBack(context);
      },
      child: ChangeNotifierProvider<JobMakerViewModel>.value(
        value: _viewModel,
        child: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              appBar: AppBar(
                title: ValueListenableBuilder(
                  valueListenable: _currentStepNotifier,
                  builder: (context, currentStep, child) {
                    final step = JobMakerSteps.values.elementAt(currentStep);
                    return Text(
                      step.getTitle(context),
                    );
                  },
                ),
              ),
              body: Column(
                children: [
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: JobMakerSteps.values.length,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (page) {
                        _currentStepNotifier.value = page;
                      },
                      itemBuilder: (context, index) {
                        final step = JobMakerSteps.values.elementAt(index);
                        return step.build(context);
                      },
                    ),
                  ),
                  Spacing.v16,
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: Spacing.d16,
                    ),
                    child: Button(
                      variant: ButtonVariant.primary,
                      label: 'Next'.hardcode,
                      onPressed: () {
                        _handleNext(context);
                      },
                    ),
                  ),
                  const BottomSpacer(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleNext(BuildContext context) async {
    final currentPage = _pageController.page?.toInt();
    if (currentPage == null || currentPage > JobMakerSteps.values.length) {
      return;
    }

    final currentStep = JobMakerSteps.values.elementAt(currentPage);
    final error = _viewModel.checkError(currentStep);
    if (error != null) {
      // TODO: show error message.
      return;
    }

    _viewModel.refreshOutputFileNames();

    if (!currentStep.isLastStep) {
      unawaited(
        _pageController.nextPage(
          duration: Durations.medium4,
          curve: Curves.easeOut,
        ),
      );
      return;
    }

    final convertJobs = await _viewModel.cook();
    if (convertJobs.isEmpty) {
      return;
    }

    context.router.pop(convertJobs);
  }

  void _handleBack(BuildContext context) {
    final currentPage = _pageController.page?.toInt();
    if (currentPage == null) {
      return;
    }

    final isFirstPage = currentPage == 0;
    final hasSelectedFiles = _viewModel.selectedFiles.isNotEmpty;
    if (isFirstPage && hasSelectedFiles) {
      // TODO: confirm popup.
      context.router.pop();
      return;
    }

    if (isFirstPage && !hasSelectedFiles) {
      context.router.pop();
      return;
    }

    _pageController.previousPage(
      duration: Durations.medium4,
      curve: Curves.easeOut,
    );
  }
}
