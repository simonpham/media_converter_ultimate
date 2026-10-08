import 'package:converter/converter.dart';
import 'package:flutter/material.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

class const SettingsPage({super.key}) extends StatefulWidget {
  static const String routeName = 'settings';
  static const String routePath = routeName;

  static void go(BuildContext context) async {
    context.router.goNamed(routeName);
  }

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final ScrollController _scrollController = .new();
  final ScrollController _sidebarScrollController = .new();

  /// The child page shown beside the list on large screens.
  SettingsPageItem? _selectedChild = SettingsPageItem.availableOptions
      .where((item) => item.child != null)
      .firstOrNull;

  @override
  void dispose() {
    _scrollController.dispose();
    _sidebarScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settingsTitle),
      ),
      body: switch (context.screenSize) {
        .small || .normal => _buildList(
          context,
          controller: _scrollController,
        ),
        .large || .larger || .extraLarge => Row(
          crossAxisAlignment: .stretch,
          children: [
            SizedBox(
              width: Spacing.d440,
              child: _buildList(
                context,
                controller: _sidebarScrollController,
                selectedChild: _selectedChild,
                onSelectChild: (item) => setState(() => _selectedChild = item),
              ),
            ),
            VerticalDivider(width: Spacing.d1),
            Expanded(
              child: switch (_selectedChild?.child) {
                final SettingsChild child => SettingsChildEmbedding(
                  key: ValueKey(child.settings),
                  child: Builder(
                    builder: (context) => Column(
                      crossAxisAlignment: .stretch,
                      children: [
                        SectionTitle(child.settings.getLabel(context)),
                        Expanded(child: child.buildContent(context)),
                      ],
                    ),
                  ),
                ),
                null => const SizedBox.shrink(),
              },
            ),
          ],
        ),
      },
    );
  }

  Widget _buildList(
    BuildContext context, {
    required ScrollController controller,
    SettingsPageItem? selectedChild,
    ValueChanged<SettingsPageItem>? onSelectChild,
  }) {
    final availableSettings = SettingsPageItem.availableOptions;
    return Scrollbar(
      controller: controller,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: controller,
        child: Column(
          crossAxisAlignment: .start,
          children: [
            for (final category in SettingsCategory.availableOptions) ...[
              SectionTitle(
                category.getLabel(context),
              ),
              Builder(
                builder: (context) {
                  final items = category.items.where(
                    (item) => availableSettings.contains(item),
                  );
                  if (items.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return ListView.builder(
                    padding: .zero,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items.elementAt(index);
                      return SettingsItem(
                        item: item,
                        isSelected: item == selectedChild,
                        onSelectChild: onSelectChild,
                      );
                    },
                  );
                },
              ),
            ],
            const BottomEmptyArea(),
          ],
        ),
      ),
    );
  }
}
