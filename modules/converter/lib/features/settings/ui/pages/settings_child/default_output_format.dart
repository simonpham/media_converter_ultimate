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
        return GridView.builder(
          padding: .all(Spacing.d16),
          itemCount: format.formats.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
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
      },
    );
  }
}
