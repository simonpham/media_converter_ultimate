part of '../config_control_widget.dart';

class SingleChoiceWidget extends StatelessWidget {
  final ConfigControl control;
  final Map<String, String> selectedValues;
  final void Function(String, String)? onChanged;

  const SingleChoiceWidget(
    this.control,
    this.selectedValues,
    this.onChanged, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final option in control.options) ...[
          CheckboxListTile(
            title: Text(context.configL10n(option.label)),
            subtitle: option.description == null
                ? null
                : Text(
                    context.configL10n('${option.description}'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
            value: selectedValues[control.name] == option.value,
            onChanged: (value) {
              if (value == null) return;
              onChanged?.call(control.name, value ? option.value : '');
            },
          ),
        ],
      ],
    );
  }
}
