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

  final MenuController _menuController = MenuController();
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
    final direction = Directionality.of(context);
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
              body: Column(
                children: [
                  ValueListenableBuilder(
                    valueListenable: _currentStepNotifier,
                    builder: (context, currentStep, child) {
                      final step = JobMakerSteps.values.elementAt(currentStep);
                      return AppBar(
                        centerTitle: true,
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              step.getTitle(context),
                              style: context.theme.textTheme.titleMedium,
                            ),
                            Spacing.v4,
                            StepperWidget(
                              stepCount: JobMakerSteps.values.length,
                              currentStep: currentStep,
                            ),
                          ],
                        ),
                        actions: step != JobMakerSteps.customizeConfigs
                            ? null
                            : [
                                Container(
                                  margin: EdgeInsets.symmetric(
                                    horizontal: Spacing.d16,
                                  ),
                                  child: Directionality(
                                    textDirection: switch (direction) {
                                      TextDirection.ltr => TextDirection.rtl,
                                      TextDirection.rtl => TextDirection.ltr,
                                    },
                                    child: Consumer<JobMakerViewModel>(
                                      builder: (context, model, child) {
                                        return MenuAnchor(
                                          controller: _menuController,
                                          alignmentOffset: Offset(
                                            0,
                                            Spacing.d4,
                                          ),
                                          menuChildren: [
                                            Directionality(
                                              textDirection: direction,
                                              child: ListItem(
                                                leading: ImageView(
                                                  Assets
                                                      .hugeicons
                                                      .stroke
                                                      .arrowsRound
                                                      .arrowTurnBackwardRound,
                                                  size: Spacing.d24,
                                                  color: context
                                                      .theme
                                                      .colorScheme
                                                      .onSurface,
                                                ),
                                                title: context
                                                    .l10n
                                                    .loadPreviousConfigs,
                                                onTap: () {
                                                  _menuController.close();
                                                  model
                                                      .loadPreviousConfigurations();
                                                },
                                              ),
                                            ),
                                            const Divider(),
                                            Directionality(
                                              textDirection: direction,
                                              child: ListItem(
                                                leading: ImageView(
                                                  Assets
                                                      .hugeicons
                                                      .stroke
                                                      .settings
                                                      .setup02,
                                                  size: Spacing.d24,
                                                  color: context
                                                      .theme
                                                      .colorScheme
                                                      .error,
                                                ),
                                                child: Text(
                                                  context.l10n.resetToDefault,
                                                  style: context
                                                      .theme
                                                      .textTheme
                                                      .bodyLarge
                                                      ?.copyWith(
                                                        color: context
                                                            .theme
                                                            .colorScheme
                                                            .error,
                                                      ),
                                                ),
                                                onTap: () {
                                                  _menuController.close();
                                                  model.resetConfigurations();
                                                },
                                              ),
                                            ),
                                          ],
                                          builder: (context, controller, _) =>
                                              Button(
                                                variant: ButtonVariant.ghost,
                                                padding: EdgeInsets.all(
                                                  Spacing.d8,
                                                ),
                                                child: ImageView(
                                                  Assets
                                                      .hugeicons
                                                      .stroke
                                                      .moreMenu
                                                      .moreVertical,
                                                  size: Spacing.d24,
                                                  color: context
                                                      .theme
                                                      .colorScheme
                                                      .onSurface,
                                                ),
                                                onPressed: () {
                                                  if (controller.isOpen) {
                                                    controller.close();
                                                    return;
                                                  }

                                                  controller.open();
                                                },
                                              ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                      );
                    },
                  ),
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
                    child: ValueListenableBuilder(
                      valueListenable: _currentStepNotifier,
                      builder: (context, currentStep, child) {
                        final isLastStep =
                            currentStep == JobMakerSteps.values.length - 1;
                        return Button(
                          variant: ButtonVariant.primary,
                          label: isLastStep
                              ? context.l10n.startConversion
                              : context.l10n.next,
                          onPressed: () {
                            _handleNext(context);
                          },
                        );
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
      context.toastFailure(error);
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

    try {
      final convertJobs = await _viewModel.cook();
      if (convertJobs.isEmpty) {
        return;
      }

      context.router.pop(convertJobs);
    } on Failure catch (failure) {
      context.toastFailure(failure);
    }
  }

  Future<void> _handleBack(BuildContext context) async {
    final currentPage = _pageController.page?.toInt();
    if (currentPage == null) {
      return;
    }

    final isFirstPage = currentPage == 0;
    final hasSelectedFiles = _viewModel.selectedFiles.isNotEmpty;
    if (isFirstPage && hasSelectedFiles) {
      final action = await ConfirmDialog.show(
        context,
        title: context.l10n.jobMakerConfirmGoBackTitle,
        message: context.l10n.jobMakerConfirmGoBackMessage,
        positiveText: context.l10n.cancel,
        negativeText: context.l10n.goBack,
      );

      final hasGoBackConfirmed = action == ConfirmAction.negative;
      if (!hasGoBackConfirmed) {
        return;
      }

      context.router.pop();
      return;
    }

    if (isFirstPage && !hasSelectedFiles) {
      context.router.pop();
      return;
    }

    unawaited(
      _pageController.previousPage(
        duration: Durations.medium4,
        curve: Curves.easeOut,
      ),
    );
  }
}
