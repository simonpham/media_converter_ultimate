import 'dart:async';

import 'package:converter/converter.dart';
import 'package:flutter/material.dart';
import 'package:icons/icons.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

class const SettingsItem({
  super.key,
  required final SettingsPageItem item,
}) extends StatefulWidget {
  @override
  State<SettingsItem> createState() => _SettingsItemState();
}

class _SettingsItemState extends State<SettingsItem> {
  bool _isOpening = false;

  Future<void> _handleOpen(BuildContext context) async {
    if (_isOpening) return;
    if (widget.item.routeName != null) {
      SettingsChild.go(context, widget.item);
      return;
    }
    setState(() => _isOpening = true);
    try {
      await widget.item.handleOpen(context);
    } finally {
      if (mounted) setState(() => _isOpening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (widget.item.settingsKeys) {
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
      margin: .only(
        top: Spacing.d8,
        left: Spacing.d16,
        right: Spacing.d16,
      ),
      child: ListItem(
        leading: Container(
          alignment: .center,
          padding: .symmetric(
            vertical: Spacing.d8,
          ),
          child: ImageView(
            widget.item.appIcon,
            size: Spacing.d24,
            color: context.theme.colorScheme.onSurface,
          ),
        ),
        title: widget.item.getLabel(context),
        subtitle: widget.item.getDescription(context),
        trailing:
            widget.item.routeName != null && widget.item.routerBuilder != null
            ? ImageView(
                Assets.arrowRight01Round,
                size: Spacing.d24,
                color: context.theme.colorScheme.onSurface,
              )
            : switch (widget.item.currentValue) {
                bool value => IgnorePointer(
                  ignoring: _isOpening,
                  child: Semantics(
                    enabled: !_isOpening,
                    child: SwitchToggle(
                      value: value,
                      onChanged: (_) => unawaited(_handleOpen(context)),
                    ),
                  ),
                ),
                _ => null,
              },
        onTap: _isOpening ? null : () => unawaited(_handleOpen(context)),
      ),
    );
  }
}
