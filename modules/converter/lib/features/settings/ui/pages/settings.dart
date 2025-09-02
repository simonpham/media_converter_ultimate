import 'package:converter/converter.dart';
import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:design_system/utils/extensions/build_context.dart';
import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  static const String routeName = 'settings';
  static const String routePath = routeName;

  static void go(BuildContext context) async {
    context.router.goNamed(routeName);
  }

  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final availableSettings = SettingsPageItem.availableOptions;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settingsTitle),
      ),
      body: CustomScrollView(
        slivers: [
          for (final category in SettingsCategory.availableOptions) ...[
            SliverToBoxAdapter(
              child: ColoredBox(
                color: context.theme.colorScheme.surface,
                child: SectionTitle(
                  category.getLabel(context),
                ),
              ),
            ),
            for (final item in category.items) ...[
              if (availableSettings.contains(item))
                SliverToBoxAdapter(
                  child: SettingsItem(
                    item: item,
                  ),
                ),
            ],
          ],
          SliverToBoxAdapter(
            child: Spacing.vertical(Spacing.d12 * 20),
          ),
        ],
      ),
    );
  }
}
