import 'package:converter/converter.dart';

final List<GoRoute> kSettingsRoutes = [
  GoRoute(
    name: SettingsPage.routeName,
    path: SettingsPage.routePath,
    builder: (_, _) => const SettingsPage(),
    routes: [
      for (final settings in SettingsPageItem.availableOptions)
        if (settings.routeName case String routeName)
          if (settings.routerBuilder case GoRouterWidgetBuilder builder)
            GoRoute(
              name: routeName,
              path: routeName,
              builder: builder,
            ),
    ],
  ),
];
