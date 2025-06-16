import 'package:converter/converter.dart';
import 'package:core/core.dart';

final kAppRouter = GoRouter(
  initialLocation: MainPage.routePath,
  routes: [
    ...kConverterRoutes,
  ],
);
