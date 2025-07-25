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
    return DropdownButton<String>(
      padding: EdgeInsets.symmetric(
        vertical: Spacing.d8,
      ),
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
    );
  }
}
