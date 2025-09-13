part of '../settings_child.dart';

class ExcludeFileExtensionsSettingsChild extends SettingsChild {
  @override
  SettingsPageItem get settings => SettingsPageItem.excludeFileExtensions;

  const ExcludeFileExtensionsSettingsChild({
    super.key,
  });

  @override
  Widget builder(BuildContext context) {
    final excludedFileExtensions = [
      ...SettingsBox().excludedFileExtensions,
    ];
    final shouldExcludeNonMediaFiles = SettingsBox().shouldExcludeNonMediaFiles;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RoundCard(
          margin: EdgeInsets.symmetric(
            horizontal: Spacing.d16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioIconListTile(
                title: context.l10n.excludeNonMediaFileExtensions,
                groupValue: shouldExcludeNonMediaFiles,
                value: true,
                onChanged: (value) {
                  SettingsBox().shouldExcludeNonMediaFiles = value;
                },
              ),
              RadioIconListTile(
                title: context.l10n.excludeCustomFileExtensions,
                groupValue: shouldExcludeNonMediaFiles,
                value: false,
                onChanged: (value) {
                  SettingsBox().shouldExcludeNonMediaFiles = value;
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: DisableWidget(
            disabled: shouldExcludeNonMediaFiles,
            child: Column(
              children: [
                Spacing.v16,
                _ExcludeFileExtensionInput(
                  onAdd: (value) {
                    excludedFileExtensions.insert(0, value);
                    SettingsBox().excludedFileExtensions =
                        excludedFileExtensions;
                  },
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: excludedFileExtensions.length,
                    padding: EdgeInsets.only(
                      top: Spacing.d16,
                      left: Spacing.d16,
                      right: Spacing.d16,
                      bottom: Spacing.d320,
                    ),
                    separatorBuilder: (context, index) => Spacing.v8,
                    itemBuilder: (context, index) {
                      final item = excludedFileExtensions[index];
                      return _ExcludeFileExtensionListItem(
                        extension: item,
                        onRemove: () {
                          excludedFileExtensions.remove(item);
                          SettingsBox().excludedFileExtensions =
                              excludedFileExtensions;
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ExcludeFileExtensionInput extends StatefulWidget {
  final ValueChanged<String> onAdd;

  const _ExcludeFileExtensionInput({
    required this.onAdd,
  });

  @override
  State<_ExcludeFileExtensionInput> createState() =>
      _ExcludeFileExtensionInputState();
}

class _ExcludeFileExtensionInputState
    extends State<_ExcludeFileExtensionInput> {
  final TextEditingController _controller = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Spacing.d16,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: InputText(
              controller: _controller,
              label: context.l10n.excludeFileExtensionsInputLabel,
              hintText: context.l10n.excludeFileExtensionsInputHint,
              textInputAction: TextInputAction.done,
              onEditingComplete: () {
                _handleAdd();
              },
            ),
          ),
          Spacing.h16,
          Button(
            variant: ButtonVariant.primary,
            label: context.l10n.add,
            onPressed: () {
              _handleAdd();
            },
          ),
        ],
      ),
    );
  }

  void _handleAdd() {
    final value = _controller.text;
    if (value.isEmpty) {
      return;
    }
    _controller.clear();
    widget.onAdd(value);
  }
}

class _ExcludeFileExtensionListItem extends StatelessWidget {
  final String extension;
  final VoidCallback onRemove;

  const _ExcludeFileExtensionListItem({
    required this.extension,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return RoundCard(
      child: ListItem(
        title: extension,
        trailing: Tappable(
          behavior: HitTestBehavior.translucent,
          child: Padding(
            padding: EdgeInsets.all(
              Spacing.d4,
            ),
            child: ImageView(
              Assets.delete01,
              size: Spacing.d24,
              color: context.theme.colorScheme.onSurface,
            ),
          ),
          onTap: onRemove,
        ),
      ),
    );
  }
}
