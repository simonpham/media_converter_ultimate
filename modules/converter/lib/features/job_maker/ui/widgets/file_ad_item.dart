import 'package:converter/constants/google_ad_units.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_ads/mobile_ads.dart';
import 'package:mobile_ads_google/mobile_ads_google.dart';

class FileAdItem extends StatefulWidget {
  const FileAdItem({
    super.key,
  });

  @override
  State<FileAdItem> createState() => _FileAdItemState();
}

class _FileAdItemState extends State<FileAdItem>
    with MobileAdsMixin, NativeAdsMixin, AfterLayoutMixin {
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
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: isAdLoadFailed
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: EdgeInsets.symmetric(
                vertical: Spacing.d4,
              ),
              child: LayoutBuilder(
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
            ),
    );
  }
}
