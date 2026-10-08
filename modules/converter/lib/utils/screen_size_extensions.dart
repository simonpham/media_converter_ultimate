import 'package:core/core.dart';
import 'package:flutter/widgets.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

extension ScreenSizeBuildContextExt on BuildContext {
  ScreenSize get screenSize => select(
    (ScreenSizeNotifier notifier) => notifier.screenSize,
  );
}
