import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

/// Configure native templates with the theme active when an ad is requested.
NativeTemplateStyle buildNativeAdTemplateStyle(
  ThemeData theme, {
  required TemplateType templateType,
}) => .new(
  templateType: templateType,
  mainBackgroundColor: theme.cardColor,
  cornerRadius: Spacing.d12,
  callToActionTextStyle: .new(
    textColor: theme.colorScheme.onPrimary,
    backgroundColor: theme.colorScheme.primary,
    style: .normal,
    size: Spacing.d16,
  ),
  primaryTextStyle: .new(
    textColor: theme.colorScheme.onSurface,
    backgroundColor: theme.cardColor,
    style: .bold,
    size: Spacing.d16,
  ),
  secondaryTextStyle: .new(
    textColor: theme.colorScheme.onSurfaceVariant,
    backgroundColor: theme.cardColor,
    style: .normal,
    size: Spacing.d14,
  ),
  tertiaryTextStyle: .new(
    textColor: theme.colorScheme.onSurfaceVariant,
    backgroundColor: theme.cardColor,
    style: .italic,
    size: Spacing.d16,
  ),
);
