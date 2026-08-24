part of '../settings_child.dart';

class const LanguagesSettingsChild({
  super.key,
}) extends SettingsChild {
  @override
  SettingsPageItem get settings => .languages;

  @override
  Widget builder(BuildContext context) {
    final languages = kSupportedLanguages.keys.toList();
    return CustomScrollView(
      slivers: [
        SliverList.separated(
          itemCount: languages.length,
          separatorBuilder: (_, _) => Spacing.v16,
          itemBuilder: (BuildContext context, int index) {
            final lang = languages[index];
            final icon = kSupportedLanguages[lang]?['icon'];
            final isSelected = SettingsBox().language == lang;
            return RoundCard(
              margin: .only(
                left: Spacing.d16,
                right: Spacing.d16,
              ),
              child: ListItem(
                leading: (icon != null)
                    ? Padding(
                        padding: .only(
                          right: Spacing.d4,
                          top: Spacing.d8,
                          bottom: Spacing.d8,
                        ),
                        child: ClipOval(
                          child: ImageView(
                            icon,
                            size: Spacing.d24,
                            fit: .cover,
                            assetPackage: null,
                          ),
                        ),
                      )
                    : null,
                title: kSupportedLanguages[lang]?['title'] ?? '',
                trailing: isSelected
                    ? ImageView(
                        Assets.tick02,
                        color: context.theme.primaryColor,
                        size: Spacing.d24,
                      )
                    : const SizedBox(),
                onTap: isSelected
                    ? null
                    : () async {
                        SettingsBox().language = lang;
                        await Future.delayed(
                          const Duration(milliseconds: 100),
                          () {
                            context.toastSuccess(
                              context.l10n.changedLanguageTo(
                                '${kSupportedLanguages[lang]?['title']}',
                              ),
                            );
                          },
                        );
                        context.navigator.pop();
                      },
              ),
            );
          },
        ),
        SliverPadding(
          padding: EdgeInsets.only(top: Spacing.d24),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: Text.rich(
                TextSpan(
                  text: 'Don\'t see your language? ',
                  style: context.theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  children: [
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Tappable(
                        onTap: () {
                          ContactUtils().sendEmail(
                            context,
                            subject: '[$kAppName] Language Support Request',
                          );
                        },
                        child: Text(
                          'Contact us',
                          style: context.theme.textTheme.titleMedium?.copyWith(
                            color: context.theme.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: BottomSpacer(),
        ),
      ],
    );
  }
}
