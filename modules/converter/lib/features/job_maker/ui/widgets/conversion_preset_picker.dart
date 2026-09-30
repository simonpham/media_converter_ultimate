import 'dart:async';

import 'package:converter/converter.dart';
import 'package:flutter/material.dart';
import 'package:icons/icons.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

class const ConversionPresetPicker({
  super.key,
  final bool currentFormatOnly = false,
}) extends StatefulWidget {
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
      final presets = model.availablePresets
          .where(
            (preset) =>
                !widget.currentFormatOnly ||
                preset.formatName == model.selectedFormatEntry?.name,
          )
          .toList();
      if (presets.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: .start,
        children: [
          SectionTitle(context.l10n.quickPresetsTitle),
          Spacing.v4,
          Text(
            context.l10n.quickPresetsDescription,
            style: context.theme.textTheme.bodyMedium,
          ),
          Spacing.v12,
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
                        child: _PresetCard(
                          preset: preset,
                          isSelected: model.selectedPreset == preset,
                          onTap: () => unawaited(model.applyPreset(preset)),
                        ),
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
}

class const _PresetCard({
  required final ConversionPreset preset,
  required final bool isSelected,
  required final VoidCallback onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colorScheme;
    final title = switch (preset) {
      .compatibleVideo => context.l10n.presetCompatibleVideo,
      .smallerVideo => context.l10n.presetSmallerVideo,
      .highQualityVideo => context.l10n.presetHighQualityVideo,
      .musicMp3 => context.l10n.presetMusicMp3,
      .compactAudio => context.l10n.presetCompactAudio,
      .losslessAudio => context.l10n.presetLosslessAudio,
    };
    final description = switch (preset) {
      .compatibleVideo => context.l10n.presetCompatibleVideoDescription,
      .smallerVideo => context.l10n.presetSmallerVideoDescription,
      .highQualityVideo => context.l10n.presetHighQualityVideoDescription,
      .musicMp3 => context.l10n.presetMusicMp3Description,
      .compactAudio => context.l10n.presetCompactAudioDescription,
      .losslessAudio => context.l10n.presetLosslessAudioDescription,
    };
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
                  if (isSelected)
                    ImageView(
                      Assets.tick02,
                      size: Spacing.d20,
                      color: colors.primary,
                    ),
                ],
              ),
              Spacing.v8,
              Text(title, style: context.theme.textTheme.titleSmall),
              Spacing.v4,
              Text(description, style: context.theme.textTheme.bodySmall),
              Spacing.v12,
              Text(
                preset.formatName.toUpperCase() +
                    (preset == .losslessAudio ? ' · ALAC' : ''),
                style: context.theme.textTheme.labelSmall?.copyWith(
                  color: colors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
