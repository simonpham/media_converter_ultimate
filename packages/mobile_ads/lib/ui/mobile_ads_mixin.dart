import 'dart:async';

import 'package:flutter/widgets.dart';

mixin MobileAdsMixin<T extends StatefulWidget> on State<T> {
  bool get isAdLoaded;

  FutureOr<void> loadAd();

  Widget? getAdWidget();
}
