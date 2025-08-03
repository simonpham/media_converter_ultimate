import 'package:core/core.dart' show injector;
import 'package:easy_hive/easy_hive.dart';

class SettingsBox extends EasyBox {
  @override
  String get boxKey => 'settings';

  factory SettingsBox() => injector<SettingsBox>();

  factory SettingsBox.create() => SettingsBox._();

  SettingsBox._();
}
