import 'dart:async';

import 'package:core/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mobile_ads/mobile_ads.dart';

mixin NativeAdsMixin<T extends StatefulWidget> on MobileAdsMixin<T> {
  NativeAd? _nativeAd;
  bool _nativeAdIsLoaded = false;
  bool _isNativeAdLoadFailed = false;

  String get adUnitId => 'ca-app-pub-3940256099942544/2247696110';

  TemplateType get templateType => TemplateType.small;

  @override
  bool get isAdLoaded => _nativeAdIsLoaded;

  @override
  bool get isAdLoadFailed => _isNativeAdLoadFailed;

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  FutureOr<void> loadAd(BuildContext context) {
    if (!isAdEnabled) {
      return null;
    }
    final theme = Theme.of(context);
    _nativeAd = NativeAd(
      adUnitId: adUnitId,
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          printLog('[NativeAdsMixin] (${T.runtimeType}) loaded: $ad');
          setState(() {
            _nativeAdIsLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          printError(
            '[NativeAdsMixin] (${T.runtimeType}) failed to load: $error',
            StackTrace.current,
          );
          ad.dispose();
          setState(() {
            _isNativeAdLoadFailed = true;
          });
        },
      ),
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: templateType,
        mainBackgroundColor: Colors.white,
        cornerRadius: 12.0,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: theme.colorScheme.primary,
          style: NativeTemplateFontStyle.normal,
          size: 16.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: theme.colorScheme.primary,
          backgroundColor:  Colors.white,
          style: NativeTemplateFontStyle.bold,
          size: 16.0,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.black54,
          backgroundColor:  Colors.white,
          style: NativeTemplateFontStyle.normal,
          size: 14.0,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.black54,
          backgroundColor:  Colors.white,
          style: NativeTemplateFontStyle.italic,
          size: 16.0,
        ),
      ),
    )..load();
  }

  @override
  Widget? getAdWidget(BoxConstraints constraint) {
    final nativeAd = _nativeAd;
    if (!isAdLoaded || nativeAd == null || !isAdEnabled) {
      return null;
    }

    return ConstrainedBox(
      constraints: constraint,
      child: AdWidget(ad: nativeAd),
    );
  }
}
