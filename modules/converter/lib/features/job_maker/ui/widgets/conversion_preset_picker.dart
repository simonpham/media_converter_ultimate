import 'dart:async';

import 'package:converter/converter.dart';
import 'package:flutter/material.dart';
import 'package:icons/icons.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

class const ConversionPresetPicker({super.key}) extends StatefulWidget {
  @override
  State<ConversionPresetPicker> createState() => _ConversionPresetPickerState();
}

class _ConversionPresetPickerState extends State<ConversionPresetPicker> {
  final ScrollController _scrollController = .new();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Consumer<JobMakerViewModel>(
    builder: (context, model, _) {
      final presets = model.availablePresets;
      if (presets.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: .start,
        children: [
          Row(
            children: [
              Expanded(
                child: SectionTitle(
                  context.l10n.quickPresetsTitle,
                  padding: .zero,
                ),
              ),
              Spacing.h8,
              Button(
                key: const ValueKey('preset-layout-toggle'),
                variant: .ghost,
                padding: .all(Spacing.d8),
                tooltip: model.showPresetGrid
                    ? context.l10n.showPresetList
                    : context.l10n.showPresetGrid,
                mainAxisSize: .min,
                child: ImageView(
                  model.showPresetGrid
                      ? Assets.horizontalList
                      : Assets.gridView,
                  size: Spacing.d24,
                  color: context.theme.colorScheme.primary,
                ),
                onPressed: model.togglePresetLayout,
              ),
            ],
          ),
          Spacing.v4,
          Text(
            context.l10n.quickPresetsDescription,
            style: context.theme.textTheme.bodyMedium,
          ),
          Spacing.v12,
          if (model.showPresetGrid)
            LayoutBuilder(
              builder: (context, constraints) {
                final scale =
                    MediaQuery.textScalerOf(context).scale(Spacing.d12) /
                    Spacing.d12;
                final minWidth = (Spacing.d96 + Spacing.d64) * scale;
                final columns =
                    ((constraints.maxWidth + Spacing.d12) /
                            (minWidth + Spacing.d12))
                        .floor()
                        .clamp(1, 3);
                return Column(
                  children: [
                    for (
                      var first = 0;
                      first < presets.length;
                      first += columns
                    ) ...[
                      if (first != 0) Spacing.v12,
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: .stretch,
                          children: [
                            for (
                              var column = 0;
                              column < columns;
                              column++
                            ) ...[
                              if (column != 0) Spacing.h12,
                              Expanded(
                                child: first + column < presets.length
                                    ? _card(model, presets[first + column])
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
            )
          else
            Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: .horizontal,
                padding: .only(bottom: Spacing.d12),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: .stretch,
                    children: [
                      for (final preset in presets) ...[
                        if (preset != presets.first) Spacing.h12,
                        SizedBox(
                          width: Spacing.d96 * 2,
                          child: _card(model, preset),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget _card(JobMakerViewModel model, ConversionPreset preset) => _PresetCard(
    preset: preset,
    isSelected: model.selectedPreset == preset,
    onTap: () {
      if (model.selectedPreset == preset) {
        model.clearPreset();
      } else {
        unawaited(model.applyPreset(preset));
      }
    },
  );
}

extension ConversionPresetLabels on ConversionPreset {
  String getTitle(BuildContext context) => switch (this) {
    .compatibleVideo => context.l10n.presetCompatibleVideo,
    .smallerVideo => context.l10n.presetSmallerVideo,
    .highQualityVideo => context.l10n.presetHighQualityVideo,
    .musicMp3 => context.l10n.presetMusicMp3,
    .compactAudio => context.l10n.presetCompactAudio,
    .losslessAudio => context.l10n.presetLosslessAudio,
  };

  String getDescription(BuildContext context) => switch (this) {
    .compatibleVideo => context.l10n.presetCompatibleVideoDescription,
    .smallerVideo => context.l10n.presetSmallerVideoDescription,
    .highQualityVideo => context.l10n.presetHighQualityVideoDescription,
    .musicMp3 => context.l10n.presetMusicMp3Description,
    .compactAudio => context.l10n.presetCompactAudioDescription,
    .losslessAudio => context.l10n.presetLosslessAudioDescription,
  };
}

class const _PresetCard({
  required final ConversionPreset preset,
  required final bool isSelected,
  required final VoidCallback onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colorScheme;
    final title = preset.getTitle(context);
    final description = preset.getDescription(context);
    return Semantics(
      button: true,
      selected: isSelected,
      child: Tappable(
        onTap: onTap,
        child: Container(
          padding: .all(Spacing.d12),
          decoration: ShapeDecoration(
            color: isSelected
                ? colors.primary.withValues(alpha: 0.08)
                : context.theme.cardColor,
            shape: RoundedSuperellipseBorder(
              borderRadius: Spacing.r12,
              side: BorderSide(
                color: isSelected ? colors.primary : colors.outlineVariant,
                width: Spacing.d1,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: .max,
            crossAxisAlignment: .start,
            children: [
              Row(
                children: [
                  ImageView(
                    preset.formatName == 'mp4'
                        ? Assets.fileVideo
                        : Assets.fileAudio,
                    size: Spacing.d24,
                    color: colors.primary,
                  ),
                  const Spacer(),
                  Text(
                    key: ValueKey('preset-format-${preset.name}'),
                    preset.formatName.toUpperCase() +
                        (preset == .losslessAudio ? ' · ALAC' : ''),
                    style: context.theme.textTheme.labelSmall?.copyWith(
                      color: colors.primary,
                    ),
                  ),
                ],
              ),
              Spacing.v8,
              Row(
                crossAxisAlignment: .start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: context.theme.textTheme.titleSmall,
                    ),
                  ),
                  if (isSelected) ...[
                    Spacing.h4,
                    ImageView(
                      Assets.tick02,
                      size: Spacing.d20,
                      color: colors.primary,
                    ),
                  ],
                ],
              ),
              Spacing.v4,
              Text(description, style: context.theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
