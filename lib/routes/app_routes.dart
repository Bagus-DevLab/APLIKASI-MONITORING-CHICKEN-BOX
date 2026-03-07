import 'package:flutter/material.dart';
// import '../pages/splash_page.dart';
import '../pagess/login_page.dart';
import '../pagess/home_page.dart';
import '../pagess/scan_page.dart';
import '../pagess/add_device_page.dart';
import '../pagess/history_page.dart';
import '../pagess/detail_device_page.dart';
import '../pagess/settings_page.dart';

class AppRoutes {
  // Route names
  static const String splash = '/';
  static const String login = '/login';
  static const String home = '/home';
  static const String scan = '/scan';
  static const String addDevice = '/add-device';
  static const String history = '/history';
  static const String detailDevice = '/detail-device';
  static const String settings = '/settings';

  // Generate routes
  static Route<dynamic> generateRoute(RouteSettings routeSettings) {
    final String? routeName = routeSettings.name;
    final Object? args = routeSettings.arguments;

    switch (routeName) {
      case splash:
        // return MaterialPageRoute(builder: (_) => const SplashPage());
      
      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage());
      
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      
      case scan:
        return MaterialPageRoute(builder: (_) => const ScanPage());
      
      case addDevice:
        return MaterialPageRoute(builder: (_) => const AddDevicePage());
      
      case history:
        return MaterialPageRoute(builder: (_) => const HistoryPage());
      
      case detailDevice:
        final deviceName = args is String ? args : 'Device';
        return MaterialPageRoute(
          builder: (_) => DetailDevicePage(deviceName: deviceName),
        );
      
      case settings:
        return MaterialPageRoute(builder: (_) => const SettingsPage());
      
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