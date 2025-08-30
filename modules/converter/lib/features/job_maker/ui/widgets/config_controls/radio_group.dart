part of '../config_control_widget.dart';

class RadioGroupWidget extends StatelessWidget {
  final ConfigControl control;
  final Map<String, String> selectedValues;
  final void Function(String, String)? onChanged;

  const RadioGroupWidget(
    this.control,
    this.selectedValues,
    this.onChanged, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: control.options.length,
      itemBuilder: (context, index) {
        final option = control.options[index];
        return RadioIconListTile(
          alignment: RadioIconAlignment.left,
          value: option.value,
          groupValue: selectedValues[control.name],
          title: context.configL10n(option.label),
          subtitle: option.description == null
              ? null
              : context.configL10n('${option.description}'),
          onChanged: (value) {
            onChanged?.call(control.name, value);
          },
        );
      },
    );
  }
}
