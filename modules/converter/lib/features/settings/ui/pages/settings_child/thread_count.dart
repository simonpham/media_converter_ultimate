part of '../settings_child.dart';

class ThreadCountSettingsChild extends SettingsChild {
  @override
  SettingsPageItem get settings => SettingsPageItem.threadCount;

  const ThreadCountSettingsChild({
    super.key,
  });

  static String getValueLabel(BuildContext context, int value) {
    if (value == 0) {
      return context.l10n.automaticSetting;
    }
    return '$value';
  }

  static const int _kMaxThreadCount = 16;

  @override
  Widget builder(BuildContext context) {
    final scrollController = ScrollController();
    final numberOfProcessors = Platform.numberOfProcessors;
    final ValueNotifier<int> threadCountNotifier = ValueNotifier(
      SettingsBox().threadCount,
    );
    final textTheme = context.theme.textTheme;
    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverPadding(
                padding: EdgeInsets.only(
                  left: Spacing.d16,
                  right: Spacing.d16,
                ),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    context.l10n.threadCountConfigDescription,
                    style: textTheme.bodyMedium,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: RoundCard(
                  margin: EdgeInsets.only(
                    top: Spacing.d16,
                    left: Spacing.d16,
                    right: Spacing.d16,
                  ),
                  padding: EdgeInsets.symmetric(vertical: Spacing.d16),
                  child: ValueListenableBuilder<int>(
                    valueListenable: threadCountNotifier,
                    builder: (context, threadCount, _) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: Spacing.d16,
                            ),
                            child: HtmlWidget(
                              context.l10n.threadCountLabel(
                                getValueLabel(
                                  context,
                                  threadCount,
                                ).html.textColor(
                                  context.theme.colorScheme.primary,
                                ),
                              ),
                              textStyle: textTheme.bodyMedium,
                            ),
                          ),
                          Slider(
                            value: threadCount.toDouble(),
                            min: 0,
                            max: _kMaxThreadCount.toDouble(),
                            divisions: _kMaxThreadCount,
                            onChanged: (value) {
                              threadCountNotifier.value = value.toInt();
                            },
                            padding: EdgeInsets.only(
                              top: Spacing.d8,
                              left: Spacing.d16,
                              right: Spacing.d16,
                              bottom: Spacing.d4,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: Spacing.d16,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    context.l10n.automaticSetting,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.labelSmall,
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    '$_kMaxThreadCount',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.labelSmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            alignment: Alignment.topCenter,
                            curve: Curves.easeOut,
                            child: switch (threadCount >= numberOfProcessors) {
                              true => Column(
                                children: [
                                  Spacing.v16,
                                  RoundCard(
                                    margin: EdgeInsets.symmetric(
                                      horizontal: Spacing.d16,
                                    ),
                                    color: Colors.amber[50],
                                    padding: EdgeInsets.all(Spacing.d16),
                                    child: HtmlWidget(
                                      ''
                                      '${context.l10n.threadCountWarningTitle.html.bold.br}'
                                      '${context.l10n.threadCountWarningMessage(numberOfProcessors, threadCount).html}',
                                      textStyle: textTheme.bodyMedium?.copyWith(
                                        color: Colors.brown[800],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              false => const SizedBox(width: double.infinity),
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: RoundCard(
                  color: Colors.transparent,
                  borderColor: context.theme.dividerColor,
                  margin: EdgeInsets.only(
                    top: Spacing.d16,
                    left: Spacing.d16,
                    right: Spacing.d16,
                  ),
                  padding: EdgeInsets.all(Spacing.d16),
                  child: HtmlWidget(
                    ''
                    '${context.l10n.threadCountDetailsTitle.html.h3}'
                    '${context.l10n.threadCountDetailsIntro.html.paragraph}'
                    '${(context.l10n.threadCountDetailsAutoBullet.html.li + context.l10n.threadCountDetailsManualBullet(numberOfProcessors).html.li).ul}'
                    '${context.l10n.threadCountDetailsConclusion.html.paragraph}',
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: BottomSpacer(),
              ),
            ],
          ),
        ),
        BottomContainer(
          scrollController: scrollController,
          child: Button(
            variant: ButtonVariant.primary,
            onPressed: () {
              final newValue = threadCountNotifier.value;
              SettingsBox().threadCount = newValue;
              context.toastSuccess(
                context.l10n.threadCountSetTo(
                  getValueLabel(context, newValue),
                ),
              );
              context.router.pop();
            },
            label: context.l10n.save,
          ),
        ),
      ],
    );
  }
}
