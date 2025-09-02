import 'package:converter/converter.dart';
import 'package:core/core.dart';

final List<GoRoute> kSettingsRoutes = [
  GoRoute(
    name: SettingsPage.routeName,
    path: SettingsPage.routePath,
    builder: (_, _) => const SettingsPage(),
    routes: [],
  ),
];
