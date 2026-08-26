import 'package:converter/converter.dart';
import 'package:flutter/material.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

class const SettingsPage({super.key}) extends StatelessWidget {
  static const String routeName = 'settings';
  static const String routePath = routeName;

  static void go(BuildContext context) async {
    context.router.goNamed(routeName);
  }

  @override
  Widget build(BuildContext context) {
    final availableSettings = SettingsPageItem.availableOptions;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settingsTitle),
      ),
      body: SingleChildScrollView(
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
                    itemBuilder: (context, index) => SettingsItem(
                      item: items.elementAt(index),
                    ),
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
