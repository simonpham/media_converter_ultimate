import 'dart:async';

import 'package:core/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mobile_ads/mobile_ads.dart';

mixin NativeAdsMixin<T extends StatefulWidget> on MobileAdsMixin {
  NativeAd? _nativeAd;
  bool _nativeAdIsLoaded = false;

  String get adUnitId => 'ca-app-pub-3940256099942544/2247696110';

  @override
  bool get isAdLoaded => _nativeAdIsLoaded;

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  FutureOr<void> loadAd() {
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
        },
      ),
      request: const AdRequest(),
      // Styling
      nativeTemplateStyle: NativeTemplateStyle(
        // Required: Choose a template.
        templateType: TemplateType.medium,
        // Optional: Customize the ad's style.
        mainBackgroundColor: Colors.purple,
        cornerRadius: 10.0,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.cyan,
          backgroundColor: Colors.red,
          style: NativeTemplateFontStyle.monospace,
          size: 16.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.red,
          backgroundColor: Colors.cyan,
          style: NativeTemplateFontStyle.italic,
          size: 16.0,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.green,
          backgroundColor: Colors.black,
          style: NativeTemplateFontStyle.bold,
          size: 16.0,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.brown,
          backgroundColor: Colors.amber,
          style: NativeTemplateFontStyle.normal,
          size: 16.0,
        ),
      ),
    )..load();
  }

  @override
  Widget? getAdWidget(BoxConstraints constraint) {
    final nativeAd = _nativeAd;
    if (!isAdLoaded || nativeAd == null) {
      return null;
    }

    return ConstrainedBox(
      constraints: constraint,
      child: AdWidget(ad: nativeAd),
    );
  }
}
