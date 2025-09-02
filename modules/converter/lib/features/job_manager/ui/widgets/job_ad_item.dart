import 'package:converter/constants/google_ad_units.dart';
import 'package:converter/data/local/ads_settings.dart';
import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_ads/mobile_ads.dart';
import 'package:mobile_ads_google/mobile_ads_google.dart';

class JobAdItem extends StatefulWidget {
  const JobAdItem({
    super.key,
  });

  @override
  State<JobAdItem> createState() => _JobAdItemState();
}

class _JobAdItemState extends State<JobAdItem>
    with MobileAdsMixin, NativeAdsMixin, AfterLayoutMixin {
  @override
  bool get isAdEnabled =>
      SettingsBox().successConversionCount >= 1 &&
      SettingsBox().appLaunchCount >= 3;

  @override
  String get adUnitId {
    if (kDebugMode) {
      return super.adUnitId;
    }

    return kJobManagerNativeAdUnitId;
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
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Spacing.v16,
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: Spacing.d16,
                  ),
                  child: Text(
                    context.l10n.adLabel,
                    style: context.theme.textTheme.labelLarge?.copyWith(
                      color: context.theme.colorScheme.primary,
                    ),
                  ),
                ),
                Spacing.v8,
                Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: Spacing.d16,
                  ),
                  child: LayoutBuilder(
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
                          shape: const SmoothRectangleBorder(
                            borderRadius: SmoothBorderRadius.all(
                              SmoothRadius(
                                cornerRadius: 12.0,
                                cornerSmoothing: 1.0,
                              ),
                            ),
                          ),
                        ),
                        padding: EdgeInsets.symmetric(
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
                ),
              ],
            ),
    );
  }
}
