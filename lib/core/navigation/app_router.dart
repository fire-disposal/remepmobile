import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/fall_detector/presentation/pages/fall_detector_page.dart';
import '../../features/mqtt_debug/presentation/pages/mqtt_debug_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../pages/app_shell_page.dart';
import '../../pages/home/dashboard_page.dart';
import '../../pages/launch_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LaunchPage(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    ShellRoute(
      builder: (context, state, child) => AppShellPage(child: child),
      routes: [
        GoRoute(
          path: '/app/fall-detector',
          builder: (context, state) => const FallDetectorPage(),
        ),
        GoRoute(
          path: '/app/mqtt-debug',
          builder: (context, state) => const MqttDebugPage(),
        ),
        GoRoute(
          path: '/app/dashboard',
          builder: (context, state) => const DashboardPage(),
        ),
        GoRoute(
          path: '/app/settings',
          builder: (context, state) => const SettingsPage(),
        ),
      ],
    ),
  ],
);
