import 'package:converter/converter.dart';
import 'package:flutter/material.dart';
import 'package:mcu/router.dart';
import 'package:mcu/theme_adapter.dart';
import 'package:sofluffy_ui/sofluffy_ui.dart';

class MediaConverterUltimate extends StatefulWidget {
  final FluffyThemeData appTheme;

  const MediaConverterUltimate({
    super.key,
    required this.appTheme,
  });

  @override
  State<MediaConverterUltimate> createState() => _MediaConverterUltimateState();
}

class _MediaConverterUltimateState extends State<MediaConverterUltimate> {
  final ScreenSizeNotifier _screenSizeNotifier = ScreenSizeNotifier();
  final JobManagerViewModel _jobManagerProvider = JobManagerViewModel();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final screenSize = ScreenSize.of(context);
    _screenSizeNotifier.updateScreenSize(screenSize);
  }

  @override
  void dispose() {
    _screenSizeNotifier.dispose();
    _jobManagerProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _jobManagerProvider),
        ChangeNotifierProvider.value(value: _screenSizeNotifier),
      ],
      child: ValueListenableBuilder(
        valueListenable: [
          CoreSettings.language,
          CoreSettings.appTheme,
        ].of(SettingsBox()),
        builder: (context, _, _) {
          final themeMode = SettingsBox().appTheme;
          return MaterialApp.router(
            theme: widget.appTheme.getTheme(isDark: false),
            darkTheme: widget.appTheme.getTheme(isDark: true),
            themeMode: themeMode,
            builder: (context, child) {
              final isDark = switch (themeMode) {
                ThemeMode.dark => true,
                ThemeMode.light => false,
                ThemeMode.system =>
                  MediaQuery.platformBrightnessOf(context) == Brightness.dark,
              };
              return FluffyTheme(
                data: widget.appTheme.getFluffyTheme(isDark: isDark),
                child: JobNotificationWrapper(
                  child: child!,
                ),
              );
            },
            routerConfig: kAppRouter,
            locale: parseLocale(
              SettingsBox().language,
            ),
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
          );
        },
      ),
    );
  }
}
