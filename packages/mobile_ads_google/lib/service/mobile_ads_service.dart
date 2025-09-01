import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:mobile_ads/service/mobile_ads_service.dart';

class GoogleMobileAdsService extends MobileAdsService {
  @override
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }
}
