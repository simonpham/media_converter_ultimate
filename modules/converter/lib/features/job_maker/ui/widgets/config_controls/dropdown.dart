part of '../config_control_widget.dart';

class const DropdownWidget(
  final ConfigControl control,
  final Map<String, String> selectedValues,
  final void Function(String, String)? onChanged, {
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = context.theme.brightness == .dark;
    return Container(
      margin: .symmetric(
        horizontal: Spacing.d16,
        vertical: Spacing.d8,
      ),
      decoration: ShapeDecoration(
        color: context.theme.colorScheme.surface,
        shape: RoundedSuperellipseBorder(
          borderRadius: Spacing.r12,
          side: BorderSide(
            color: isDark
                ? context.appTheme.colors.neutral5
                : context.appTheme.colors.neutral2,
            width: 2.0,
          ),
        ),
      ),
      child: DropdownButton<String>(
        dropdownColor: context.theme.colorScheme.surface,
        borderRadius: Spacing.r12,
        padding: .symmetric(
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
