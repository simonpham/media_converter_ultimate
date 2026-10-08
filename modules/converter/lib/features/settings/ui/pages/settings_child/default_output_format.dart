part of '../settings_child.dart';

class const DefaultOutputFormatSettingsChild({
  super.key,
}) extends SettingsChild {
  @override
  SettingsPageItem get settings => .defaultOutputFormat;

  @override
  Widget builder(BuildContext context) {
    final selectedFormat = SettingsBox().defaultOutputFormat;
    return FutureBuilder<FormatConfigModel?>(
      future: FormatConfigModel.get(context),
      builder: (context, snapshot) {
        final format = snapshot.data;
        if (format == null) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        final formatConfigModel = format;
        final grid = GridView.builder(
          padding: .all(Spacing.d16),
          itemCount: format.formats.length,
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: Spacing.d96,
            crossAxisSpacing: Spacing.d16,
            mainAxisSpacing: Spacing.d16,
          ),
          itemBuilder: (BuildContext context, int index) {
            final item = format.formats[index];
            final isSelected = selectedFormat == item.name;
            return OutputFormatGridItem(
              config: formatConfigModel,
              format: item,
              isSelected: isSelected,
              onTap: () {
                SettingsBox().defaultOutputFormat = item.name;
                context.toastSuccess(
                  context.l10n.settingsDefaultOutputFormatChanged(
                    item.name.toUpperCase(),
                  ),
                );
              },
            );
          },
        );
        return Column(
          crossAxisAlignment: .stretch,
          children: [
            Expanded(child: grid),
            if (selectedFormat != null)
              Padding(
                padding: .all(Spacing.d16),
                child: Column(
                  crossAxisAlignment: .stretch,
                  children: [
                    Button(
                      key: const ValueKey('clear-default-output-format'),
                      variant: .ghost,
                      titleExpand: .shrink,
                      child: Text(
                        context.l10n.clearDefaultOutputFormat,
                        textAlign: .center,
                      ),
                      onPressed: () {
                        SettingsBox().defaultOutputFormat = null;
                        context.toastSuccess(
                          context.l10n.settingsDefaultOutputFormatCleared,
                        );
                      },
                    ),
                    Spacing.v8,
                    Text(
                      context.l10n.clearDefaultOutputFormatHint,
                      style: context.theme.textTheme.bodySmall,
                      textAlign: .center,
                    ),
                  ],
                ),
              ),
            const BottomSpacer(),
          ],
        );
      },
    );
  }
}
