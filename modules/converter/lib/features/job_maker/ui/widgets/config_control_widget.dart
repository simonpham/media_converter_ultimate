import 'dart:convert';

import 'package:converter/converter.dart';
import 'package:flutter/material.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

part 'config_controls/dropdown.dart';
part 'config_controls/multi_choice.dart';
part 'config_controls/radio_group.dart';
part 'config_controls/single_choice.dart';

class const ConfigControlWidget(
  final ConfigControl control, {
  super.key,
  required final Map<String, String> selectedValues,
  final void Function(String, String)? onChanged,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final labelWidget = SectionTitle(
      context.configL10n(control.label),
      padding: .zero,
    );
    final controlWidget = switch (control.type) {
      .multiChoice => MultiChoiceWidget(
        control,
        selectedValues,
        onChanged,
      ),
      .radioGroup => RadioGroupWidget(
        control,
        selectedValues,
        onChanged,
      ),
      .singleChoice => SingleChoiceWidget(
        control,
        selectedValues,
        onChanged,
      ),
      .dropdown => DropdownWidget(
        control,
        selectedValues,
        onChanged,
      ),
      _ => Text(
        'Unsupported control type: ${control.type}',
      ),
    };

    return Column(
      crossAxisAlignment: .start,
      children: [
        Padding(
          padding: .only(
            left: Spacing.d16,
            right: Spacing.d16,
            top: Spacing.d16,
          ),
          child: labelWidget,
        ),
        Spacing.v8,
        controlWidget,
      ],
    );
  }
}
