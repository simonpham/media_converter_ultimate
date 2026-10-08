import 'package:converter/constants/google_ad_units.dart';
import 'package:converter/data/local/ads_settings.dart';
import 'package:core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_ads/mobile_ads.dart';
import 'package:mobile_ads_google/mobile_ads_google.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

class const OutputFormatAdItem({super.key}) extends StatefulWidget {
  @override
  State<OutputFormatAdItem> createState() => _OutputFormatAdItemState();
}

class _OutputFormatAdItemState extends State<OutputFormatAdItem>
    with MobileAdsMixin, NativeAdsMixin, AfterLayoutMixin {
  @override
  bool get isAdEnabled =>
      SettingsBox().successConversionCount >= 1 &&
      SettingsBox().outputFormatPickerAccessCount >= 3;

  @override
  String get adUnitId {
    if (kDebugMode) {
      return super.adUnitId;
    }

    return GoogleAdUnits.outputFormatPicker;
  }

  @override
  void afterFirstLayout(BuildContext context) {
    loadAd(context);
  }

  @override
  Widget build(BuildContext context) {
    if (!isAdEnabled) {
      return const SizedBox.shrink();
    }
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: isAdLoadFailed
          ? const SizedBox(width: double.infinity)
          : Column(
              mainAxisSize: .min,
              crossAxisAlignment: .start,
              children: [
                Text(
                  context.l10n.adLabel,
                  style: context.theme.textTheme.labelLarge?.copyWith(
                    color: context.theme.colorScheme.primary,
                  ),
                ),
                Spacing.v8,
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (!isAdLoaded) {
                      return LoadingBox(
                        width: constraints.maxWidth,
                        height: Spacing.d96 + 2 * Spacing.d16,
                      );
                    }
                    final widget = Container(
                      decoration: ShapeDecoration(
                        color: context.theme.cardColor,
                        shape: const RoundedSuperellipseBorder(
                          borderRadius: Spacing.r12,
                        ),
                      ),
                      padding: .symmetric(
                        vertical: Spacing.d16,
                        horizontal: Spacing.d16,
                      ),
                      child: getAdWidget(
                        constraints.copyWith(
                          maxHeight: Spacing.d96,
                        ),
                      ),
                    );
                    return widget;
                  },
                ),
                Spacing.v16,
              ],
            ),
    );
  }
}
