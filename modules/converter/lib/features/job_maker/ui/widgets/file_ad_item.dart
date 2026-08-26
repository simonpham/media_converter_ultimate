import 'package:converter/constants/google_ad_units.dart';
import 'package:converter/data/local/ads_settings.dart';
import 'package:core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_ads/mobile_ads.dart';
import 'package:mobile_ads_google/mobile_ads_google.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

class const FileAdItem({super.key}) extends StatefulWidget {
  @override
  State<FileAdItem> createState() => _FileAdItemState();
}

class _FileAdItemState extends State<FileAdItem>
    with MobileAdsMixin, NativeAdsMixin, AfterLayoutMixin {
  @override
  bool get isAdEnabled =>
      SettingsBox().successConversionCount >= 1 &&
      SettingsBox().filePickerAccessCount >= 2;

  @override
  String get adUnitId {
    if (kDebugMode) {
      return super.adUnitId;
    }

    return kFilePickerNativeAdUnitId;
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
          : Padding(
              padding: .symmetric(
                horizontal: Spacing.d16,
              ),
              child: Column(
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
                          height: Spacing.d96 + 2 * Spacing.d12,
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
                          horizontal: Spacing.d12,
                          vertical: Spacing.d12,
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
                ],
              ),
            ),
    );
  }
}
