import 'package:converter/converter.dart';
import 'package:flutter/material.dart';
import 'package:icons/icons.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

class const HomePresetShortcuts({
  super.key,
  required final ValueChanged<ConversionPreset> onSelected,
  final bool enabled = true,
}) extends StatefulWidget {
  @override
  State<HomePresetShortcuts> createState() => _HomePresetShortcutsState();
}

class _HomePresetShortcutsState extends State<HomePresetShortcuts> {
  Future<FormatConfigModel?>? _formats;
  bool _expanded = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _formats ??= FormatConfigModel.get(context);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<FormatConfigModel?>(
    future: _formats,
    builder: (context, snapshot) {
      final config = snapshot.data;
      if (config == null) return const SizedBox.shrink();
      final presets = ConversionPreset.forFormats(
        config.formats.map((format) => format.name),
      );
      if (presets.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: .all(Spacing.d16),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            Row(
              children: [
                Expanded(
                  child: SectionTitle(
                    context.l10n.quickConvertTitle,
                    padding: .zero,
                  ),
                ),
                Spacing.h8,
                Button(
                  key: const ValueKey('home-presets-toggle'),
                  variant: .ghost,
                  padding: .all(Spacing.d8),
                  mainAxisSize: .min,
                  tooltip: _expanded
                      ? context.l10n.hideQuickPresets
                      : context.l10n.showQuickPresets,
                  child: RotatedBox(
                    quarterTurns: _expanded ? 3 : 1,
                    child: ImageView(
                      Assets.arrowRight01Round,
                      size: Spacing.d24,
                      color: context.theme.colorScheme.primary,
                    ),
                  ),
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              ],
            ),
            if (_expanded) ...[
              Spacing.v8,
              ConversionPresetPicker(
                presets: presets,
                compact: true,
                enabled: widget.enabled,
                formatGradients: config.uiGradients,
                onSelected: widget.onSelected,
              ),
            ],
          ],
        ),
      );
    },
  );
}
