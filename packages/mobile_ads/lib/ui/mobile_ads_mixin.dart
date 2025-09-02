import 'dart:async';

import 'package:flutter/widgets.dart';

mixin MobileAdsMixin<T extends StatefulWidget> on State<T> {
  bool get isAdEnabled;

  bool get isAdLoaded;

  bool get isAdLoadFailed;

  FutureOr<void> loadAd(BuildContext context);

  Widget? getAdWidget(BoxConstraints constraint);
}
