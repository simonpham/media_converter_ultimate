import 'package:converter/converter.dart';

final List<GoRoute> kConverterRoutes = [
  GoRoute(
    name: MainPage.routeName,
    path: MainPage.routePath,
    builder: (_, _) => const MainPage(),
    routes: [
      GoRoute(
        name: JobMaker.routeName,
        path: JobMaker.routePath,
        builder: (_, state) => JobMaker.fromRouterState(state),
      ),
      ...kSettingsRoutes,
    ],
  ),
];
