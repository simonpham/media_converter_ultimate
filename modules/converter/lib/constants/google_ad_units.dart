import 'package:core/core.dart';
import 'package:flutter/services.dart';

/// Native ad unit IDs. Gradle builds them into Android resources from
/// `.assets/env.props`; [load] reads them once at startup. Until then, or
/// without real IDs, Google's sample native ad unit is used, so forks never
/// serve ads on the production account.
abstract final class GoogleAdUnits {
  static const MethodChannel _channel = .new('io.sofluffy.mcu/ad_units');
  static const String _testNativeAdUnitId =
      'ca-app-pub-3940256099942544/2247696110';
  static Map<String, String> _ids = const {};

  static Future<void> load() async {
    try {
      _ids =
          await _channel.invokeMapMethod<String, String>('getAdUnitIds') ??
          const {};
    } catch (error, trace) {
      printError(error, trace);
    }
  }

  static String get jobManager => _ids['jobManager'] ?? _testNativeAdUnitId;

  static String get filePicker => _ids['filePicker'] ?? _testNativeAdUnitId;

  static String get outputFormatPicker =>
      _ids['outputFormatPicker'] ?? _testNativeAdUnitId;

  static String get previewPage => _ids['previewPage'] ?? _testNativeAdUnitId;
}
