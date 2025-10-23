#!/usr/bin/env dart
import 'dart:async';

import 'package:mcu_configs/mcu_configs.dart' as mcu;

/// Entrypoint for the `mcu_configs` executable.
///
/// This delegates to the library implementation in `lib/mcu_configs.dart`,
/// allowing the package to be run via:
///   dart run mcu_configs
Future<void> main(List<String> args) async {
  await mcu.main(args);
}