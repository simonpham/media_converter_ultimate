import 'package:converter/converter.dart';

final kAppRouter = GoRouter(
  initialLocation: MainPage.routePath,
  routes: [
    ...kConverterRoutes,
  ],
);
