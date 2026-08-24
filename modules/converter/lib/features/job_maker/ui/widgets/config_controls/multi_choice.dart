part of '../config_control_widget.dart';

class const MultiChoiceWidget(
  final ConfigControl control,
  final Map<String, String> selectedValues,
  final void Function(String, String)? onChanged, {
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final List<String> selectedValuesList = List<String>.from(
      jsonDecode(selectedValues[control.name] ?? '[]'),
    );
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: .zero,
      itemCount: control.options.length,
      itemBuilder: (context, index) {
        final option = control.options[index];
        final value = option.value;
        final isSelected = selectedValuesList.contains(value);
        return CheckBoxListTile(
          value: isSelected,
          title: context.configL10n(option.label),
          subtitle: option.description == null
              ? null
              : context.configL10n('${option.description}'),
          onChanged: (_) {
            if (value.isEmpty) {
              return;
            }
            final newValues = [...selectedValuesList];
            if (newValues.contains(value)) {
              newValues.remove(value);
            } else {
              newValues.add(value);
            }
            onChanged?.call(control.name, jsonEncode(newValues));
          },
        );
      },
    );
  }
}
