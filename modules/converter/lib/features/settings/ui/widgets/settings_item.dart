import 'package:converter/converter.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

class SettingsItem extends StatelessWidget {
  final SettingsPageItem item;

  const SettingsItem({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return ListItem(
      leading: Padding(
        padding: EdgeInsets.symmetric(
          vertical: Spacing.d4,
        ),
        child: ImageView(
          item.appIcon,
          size: Spacing.d24,
        ),
      ),
      title: item.getLabel(context),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {},
    );
  }
}
