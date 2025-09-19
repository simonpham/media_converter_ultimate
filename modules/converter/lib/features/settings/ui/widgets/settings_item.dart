import 'package:converter/converter.dart';
import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:icons/icons.dart';

class SettingsItem extends StatelessWidget {
  final SettingsPageItem item;

  const SettingsItem({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return switch (item.settingsKeys) {
      List<Enum> keys when keys.isNotEmpty => ValueListenableBuilder(
        valueListenable: keys.of(SettingsBox()),
        builder: (context, _, _) {
          return builder(context);
        },
      ),
      _ => builder(context),
    };
  }

  Widget builder(BuildContext context) {
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
        subtitle: item.getDescription(context),
        trailing: item.routeName != null && item.routerBuilder != null
            ? ImageView(
                Assets.arrowRight01Round,
                size: Spacing.d24,
                color: context.theme.colorScheme.onSurface,
              )
            : switch (item.currentValue) {
                bool value => SwitchToggle(
                  value: value,
                  onChanged: (_) {
                    SettingsChild.go(context, item);
                  },
                ),
                _ => null,
              },
        onTap: () {
          SettingsChild.go(context, item);
        },
      ),
    );
  }
}
