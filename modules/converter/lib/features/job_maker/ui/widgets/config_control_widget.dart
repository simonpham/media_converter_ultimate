import 'dart:convert';

import 'package:converter/converter.dart';
import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

part 'config_controls/multi_choice.dart';
part 'config_controls/radio_group.dart';
part 'config_controls/single_choice.dart';
part 'config_controls/dropdown.dart';

class ConfigControlWidget extends StatelessWidget {
  final ConfigControl control;
  final Map<String, String> selectedValues;

  final void Function(String, String)? onChanged;

  const ConfigControlWidget(
    this.control, {
    required this.selectedValues,
    this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final labelWidget = Text(
      context.configL10n(control.name),
      style: Theme.of(context).textTheme.titleMedium,
    );
    final controlWidget = switch (control.type) {
      ConfigControlType.multiChoice => MultiChoiceWidget(
        control,
        selectedValues,
        onChanged,
      ),
      ConfigControlType.radioGroup => RadioGroupWidget(
        control,
        selectedValues,
        onChanged,
      ),
      ConfigControlType.singleChoice => SingleChoiceWidget(
        control,
        selectedValues,
        onChanged,
      ),
      ConfigControlType.dropdown => DropdownWidget(
        control,
        selectedValues,
        onChanged,
      ),
      _ => Text(
        'Unsupported control type: ${control.type}',
      ),
    };

    if ([ConfigControlType.dropdown].contains(control.type)) {
      return Padding(
        padding: EdgeInsets.only(
          left: Spacing.d16,
          right: Spacing.d16,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            labelWidget,
            Spacing.h16,
            Expanded(child: controlWidget),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
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
