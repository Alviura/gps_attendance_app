import 'package:flutter/material.dart';

import 'app_branding.dart';
import '../screens/home_screen.dart';
import '../screens/splash_screen.dart';
import '../services/backend_status.dart';

class GpsAttendanceApp extends StatelessWidget {
  const GpsAttendanceApp({
    super.key,
    this.backendStatus = const BackendStatus.firebase(),
  });

  final BackendStatus backendStatus;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(AppBranding.seedColorValue),
      brightness: Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppBranding.appName,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      home: _AppRoot(backendStatus: backendStatus),
    );
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot({required this.backendStatus});
  final BackendStatus backendStatus;

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashScreen(
        onDone: () => setState(() => _showSplash = false),
      );
    }
    return AuthGate(backendStatus: widget.backendStatus);
  }
}
