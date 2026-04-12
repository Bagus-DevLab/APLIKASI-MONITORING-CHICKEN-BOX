import 'package:flutter/material.dart';
// import '../pages/splash_page.dart';
import '../pages/login_page.dart';
import '../pages/register_page.dart';
import '../pages/home_screen.dart';
// ignore: unused_import
import '../pages/home_page.dart';
import '../pages/scan_page.dart';
import '../pages/devices_page.dart';
import '../pages/history_page.dart';
import '../pages/profile_page.dart';

class AppRoutes {
  // Route names
  static const String login = '/';
  static const String splash = '/';
  static const String register = '/register';
  static const String home = '/home';
  static const String devices = '/devices';
  static const String scan = '/scan';
  static const String history = '/history';
  static const String profile = '/profile';

  // Generate routes
  static Route<dynamic> generateRoute(RouteSettings routeSettings) {
    final String? routeName = routeSettings.name;
    // ignore: unused_local_variable
    final Object? args = routeSettings.arguments;

    switch (routeName) {
      case login:
      // ignore: unreachable_switch_case
      case splash:
        return MaterialPageRoute(builder: (_) => const LoginPage());

      case register:
        return MaterialPageRoute(builder: (_) => const RegisterPage());

      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());

      case devices:
        return MaterialPageRoute(builder: (_) => const DevicesPage());

      case scan:
        return MaterialPageRoute(builder: (_) => const ScanPage());

      case history:
        return MaterialPageRoute(builder: (_) => const HistoryPage());

      case profile:
        return MaterialPageRoute(builder: (_) => const ProfilePage());

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('404')),
            body: const Center(child: Text('Halaman tidak ditemukan')),
          ),
        );
    }
  }
}