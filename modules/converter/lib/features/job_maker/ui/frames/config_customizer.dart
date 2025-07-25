import 'dart:convert';

import 'package:converter/converter.dart';
import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

class JobMakerConfigCustomizer extends StatelessWidget {
  final Map<String, List<ConfigControl>> configControls;

  final FormatEntry selectedFormat;
  final Map<String, String> selectedValues;
  final void Function(String, String)? onChanged;

  const JobMakerConfigCustomizer({
    super.key,
    required this.configControls,
    required this.selectedFormat,
    required this.selectedValues,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> selectedKeys = [];
    for (final value in selectedValues.values) {
      try {
        final valueAsList = List<String>.from(jsonDecode(value));
        selectedKeys.addAll(valueAsList);
        continue;
      } catch (_) {}
      selectedKeys.add(value);
    }
    final List<String> keys = [
      selectedFormat.name,
      ?switch (selectedFormat.outputType) {
        OutputType.audio => kCommonAudioKey,
        OutputType.video => kCommonVideoKey,
        _ => null,
      },
    ];

    final List<ConfigControl> controls = [];
    for (final key in keys) {
      final controlsOfKey = configControls[key];
      if (controlsOfKey is! List<ConfigControl>) {
        continue;
      }
      for (final control in controlsOfKey) {
        controls.add(control);

        for (final option in control.options) {
          final value = option.value;
          if (!selectedKeys.contains(value)) {
            continue;
          }

          final controlOfValue = configControls[value];
          if (controlOfValue is! List<ConfigControl>) {
            continue;
          }

          controls.addAll(controlOfValue);
        }
      }
    }

    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverList.separated(
                separatorBuilder: (context, index) => const Divider(),
                itemCount: controls.length,
                itemBuilder: (context, index) {
                  final control = controls[index];
                  return ConfigControlWidget(
                    control,
                    selectedValues: selectedValues,
                    onChanged: onChanged,
                  );
                },
              ),
              const SliverToBoxAdapter(
                child: BottomSpacer(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
