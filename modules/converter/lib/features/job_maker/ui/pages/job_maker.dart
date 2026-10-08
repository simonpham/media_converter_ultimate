import 'dart:async';

import 'package:converter/converter.dart';
import 'package:flutter/material.dart';
import 'package:icons/icons.dart';
import 'package:platform_utils/platform_utils.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

class const JobMaker({
  super.key,
  required final FormatConfigModel formatConfigModel,
  required final Map<String, String?> translations,
  final ConversionPreset? initialPreset,
  final JobSubmission? onSubmitJobs,
}) extends StatefulWidget {
  static const String routeName = 'job-maker';
  static const String routePath = routeName;

  /// Whether the wizard shows its review panel beside the steps.
  static bool hasReviewPanel(ScreenSize screenSize) => switch (screenSize) {
    .small || .normal || .large => false,
    .larger || .extraLarge => true,
  };

  static Future<List<ConvertJob>> cook(
    BuildContext context, {
    ConversionPreset? initialPreset,
    JobSubmission? onSubmitJobs,
  }) async {
    final formatConfigModel = await FormatConfigModel.get(context);
    if (formatConfigModel == null) {
      return const [];
    }

    final Map<String, String?> translations = {
      ...await ConfigTranslations.get(
        context,
        locale: kDefaultLanguage,
      ),
      ...await ConfigTranslations.get(
        context,
        locale: SettingsBox().language,
      ),
    };

    if (Platform.isAndroid &&
        {
          '/storage/emulated/0/Download/MediaConverterPro',
          '/sdcard/Download/MediaConverterPro',
        }.contains(SettingsBox().lastOutputDirectoryPath)) {
      final downloads = await injector<FileService>().getDownloadsDestination();
      if (downloads != null) SettingsBox().lastOutputDirectoryPath = downloads;
    }
    SettingsBox().lastOutputDirectoryPath ??=
        await JobMakerPathUtils.getDefaultOutputDirectoryPath();

    if (!context.mounted) return const [];

    final result = await context.router.pushNamed(
      routeName,
      extra: (formatConfigModel, translations, initialPreset, onSubmitJobs),
    );
    if (result is! List<ConvertJob> || result.isEmpty) {
      return const [];
    }

    return result;
  }

  static JobMaker fromRouterState(GoRouterState state) {
    final (
      formatConfigModel,
      translations,
      preset,
      onSubmitJobs,
    ) = switch (state.extra) {
      (
        FormatConfigModel config,
        Map<String, String?> translations,
        ConversionPreset? preset,
        JobSubmission? onSubmitJobs,
      ) =>
        (config, translations, preset, onSubmitJobs),
      (
        FormatConfigModel config,
        Map<String, String?> translations,
        ConversionPreset? preset,
      ) =>
        (config, translations, preset, null),
      (FormatConfigModel config, Map<String, String?> translations) => (
        config,
        translations,
        null,
        null,
      ),
      _ => throw ArgumentError('Invalid conversion setup arguments'),
    };
    return JobMaker(
      formatConfigModel: formatConfigModel,
      translations: translations,
      initialPreset: preset,
      onSubmitJobs: onSubmitJobs,
    );
  }

  @override
  State<JobMaker> createState() => _JobMakerState();
}

class _JobMakerState extends State<JobMaker> {
  late final JobMakerViewModel _viewModel = .new(
    formatConfigModel: widget.formatConfigModel,
    translations: widget.translations,
  );

  final MenuController _menuController = .new();
  final PageController _pageController = .new();
  final ValueNotifier<int> _currentStepNotifier = .new(0);
  bool _isChangingStep = false;
  late final bool _isPresetShortcut =
      widget.initialPreset != null &&
      _viewModel.availablePresets.contains(widget.initialPreset);
  late final List<JobMakerSteps> _steps = [
    JobMakerSteps.pickFiles,
    if (!_isPresetShortcut) JobMakerSteps.chooseOutputFormat,
    JobMakerSteps.customizeConfigs,
    JobMakerSteps.preview,
  ];

  @override
  void initState() {
    super.initState();
    if (_isPresetShortcut) {
      unawaited(_viewModel.applyPreset(widget.initialPreset!));
    }
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _currentStepNotifier.dispose();
    _pageController.dispose();
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
                      final step = _steps[currentStep];
                      return AppBar(
                        centerTitle: true,
                        title: Column(
                          crossAxisAlignment: .center,
                          children: [
                            Text(
                              step.getTitle(context),
                              style: context.theme.textTheme.titleMedium,
                            ),
                            Spacing.v4,
                            StepperWidget(
                              stepCount: _steps.length,
                              currentStep: currentStep,
                            ),
                          ],
                        ),
                        actions: step != JobMakerSteps.customizeConfigs
                            ? null
                            : [
                                Container(
                                  margin: .symmetric(
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
                                          alignmentOffset: .new(
                                            0,
                                            Spacing.d4,
                                          ),
                                          menuChildren: [
                                            Directionality(
                                              textDirection: direction,
                                              child: ListItem(
                                                leading: ImageView(
                                                  Assets.arrowTurnBackwardRound,
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
                                                  Assets.setup02,
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
                                                variant: .ghost,
                                                padding: .all(
                                                  Spacing.d8,
                                                ),
                                                child: ImageView(
                                                  Assets.moreVertical,
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
                    child: Row(
                      crossAxisAlignment: .stretch,
                      children: [
                        Expanded(
                          child: AdaptiveContent(
                            child: Column(
                              children: [
                                Expanded(
                                  child: Consumer<JobMakerViewModel>(
                                    builder: (context, model, _) => AbsorbPointer(
                                      absorbing: model.isPreparingJobs,
                                      child: PageView.builder(
                                        controller: _pageController,
                                        itemCount: _steps.length,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        onPageChanged: (page) {
                                          _currentStepNotifier.value = page;
                                        },
                                        itemBuilder: (context, index) {
                                          final step = _steps[index];
                                          return step.build(
                                            context,
                                            showPresetSelection:
                                                _isPresetShortcut,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                Spacing.v16,
                                Padding(
                                  padding: .symmetric(
                                    horizontal: Spacing.d16,
                                  ),
                                  child: ValueListenableBuilder(
                                    valueListenable: _currentStepNotifier,
                                    builder: (context, currentStep, child) {
                                      final isLastStep =
                                          currentStep == _steps.length - 1;
                                      return Consumer<JobMakerViewModel>(
                                        builder: (context, model, _) => Button(
                                          variant: .primary,
                                          enable:
                                              !model.isLoadingFormat &&
                                              !model.isPreparingJobs &&
                                              !model.isPickingFiles &&
                                              !_isChangingStep,
                                          label: model.isPreparingJobs
                                              ? context.l10n.preparingJobs
                                              : isLastStep
                                              ? context.l10n.startConversion
                                              : context.l10n.next,
                                          onPressed: () {
                                            unawaited(_handleNext(context));
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (JobMaker.hasReviewPanel(context.screenSize)) ...[
                          VerticalDivider(width: Spacing.d1),
                          SizedBox(
                            width: Spacing.d360,
                            child: const JobMakerReviewPanel(),
                          ),
                        ],
                      ],
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
    if (_isChangingStep ||
        _viewModel.isPreparingJobs ||
        _viewModel.isPickingFiles ||
        _viewModel.isLoadingFormat) {
      return;
    }
    final currentPage = _pageController.page?.toInt();
    if (currentPage == null || currentPage >= _steps.length) {
      return;
    }

    final currentStep = _steps[currentPage];
    final error = _viewModel.checkError(currentStep);
    if (error != null) {
      context.toastFailure(error);
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    _viewModel.refreshOutputFileNames();

    setState(() => _isChangingStep = true);
    try {
      if (!currentStep.isLastStep) {
        await _pageController.nextPage(
          duration: Durations.medium4,
          curve: Curves.easeOut,
        );
        return;
      }
      final convertJobs = await _viewModel.cook(
        onSubmitJobs: widget.onSubmitJobs,
      );
      if (!mounted || convertJobs.isEmpty) {
        return;
      }

      context.router.pop(convertJobs);
    } on Failure catch (failure) {
      if (mounted) context.toastFailure(failure);
    } catch (error, trace) {
      printError(error, trace);
      if (mounted) context.toastFailure(Failure(error.toString()));
    } finally {
      if (mounted) setState(() => _isChangingStep = false);
    }
  }

  Future<void> _handleBack(BuildContext context) async {
    if (_isChangingStep || _viewModel.isPreparingJobs) return;
    FocusManager.instance.primaryFocus?.unfocus();
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

      final hasGoBackConfirmed = action == .negative;
      if (!mounted || !hasGoBackConfirmed) {
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
