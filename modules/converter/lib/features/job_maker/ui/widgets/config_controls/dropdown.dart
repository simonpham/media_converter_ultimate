part of '../config_control_widget.dart';

class DropdownWidget extends StatelessWidget {
  final ConfigControl control;
  final Map<String, String> selectedValues;
  final void Function(String, String)? onChanged;

  const DropdownWidget(
    this.control,
    this.selectedValues,
    this.onChanged, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.theme.brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.symmetric(
        vertical: Spacing.d8,
      ),
      decoration: ShapeDecoration(
        color: context.theme.colorScheme.surface,
        shape: SmoothRectangleBorder(
          borderRadius: Spacing.smoothR12,
          side: BorderSide(
            color: isDark
                ? ThemeConfigs().theme.colors.neutral5
                : ThemeConfigs().theme.colors.neutral2,
            width: 2.0,
          ),
        ),
      ),
      child: DropdownButton<String>(
        dropdownColor: context.theme.colorScheme.surface,
        borderRadius: Spacing.smoothR12,
        padding: EdgeInsets.symmetric(
          horizontal: Spacing.d16,
        ),
        underline: const SizedBox(),
        isExpanded: true,
        value: selectedValues[control.name],
        items: control.options
            .map(
              (e) => DropdownMenuItem(
                value: e.value,
                child: Text(
                  context.configL10n(e.label),
                ),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value == null) return;
          onChanged?.call(control.name, value);
        },
      ),
    );
  }
}
