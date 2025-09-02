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
    return RoundCard(
      margin: EdgeInsets.only(
        top: Spacing.d8,
        left: Spacing.d16,
        right: Spacing.d16,
      ),
      child: ListItem(
        leading: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(
            vertical: Spacing.d8,
          ),
          child: ImageView(
            item.appIcon,
            size: Spacing.d24,
            color: context.theme.colorScheme.onSurface,
          ),
        ),
        title: item.getLabel(context),
        trailing: ImageView(
          Assets.hugeicons.stroke.arrowsRound.arrowRight01Round,
          size: Spacing.d24,
          color: context.theme.colorScheme.onSurface,
        ),
        onTap: () {
          SettingsChild.go(context, item);
        },
      ),
    );
  }
}
