import 'dart:convert';

import 'package:converter/converter.dart';
import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

class JobMakerConfigCustomizer extends StatelessWidget {
  final List<ConfigControl> availableControls;

  final Map<String, String> selectedValues;
  final void Function(String, String)? onChanged;

  const JobMakerConfigCustomizer({
    super.key,
    required this.availableControls,
    required this.selectedValues,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverList.separated(
                separatorBuilder: (context, index) => const Divider(),
                itemCount: availableControls.length,
                itemBuilder: (context, index) {
                  final control = availableControls[index];
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
