part of '../config_control_widget.dart';

class MultiChoiceWidget extends StatelessWidget {
  final ConfigControl control;
  final Map<String, String> selectedValues;
  final void Function(String, String)? onChanged;

  const MultiChoiceWidget(
    this.control,
    this.selectedValues,
    this.onChanged, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> selectedValuesList = List<String>.from(
      jsonDecode(selectedValues[control.name] ?? '[]'),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final option in control.options) ...[
          Builder(
            builder: (context) {
              final value = option.value;
              final isSelected = selectedValuesList.contains(value);
              return CheckboxListTile(
                title: Text(context.configL10n(option.label)),
                subtitle: option.description == null
                    ? null
                    : Text(
                        context.configL10n('${option.description}'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                value: isSelected,
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
          ),
        ],
      ],
    );
  }
}
