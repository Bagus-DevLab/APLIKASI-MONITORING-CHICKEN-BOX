import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;
import 'constants/app_colors.dart';
import 'routes/app_routes.dart';
import 'package:firebase_core/firebase_core.dart';
import 'constants/api_config.dart';
import 'core/network/token_manager.dart';
import 'core/network/auth_interceptor.dart';
import 'providers/device_provider.dart';

import 'pages/login_page.dart';
import 'pages/home_screen.dart';
import 'widgets/offline_banner.dart';

/// Global navigator key — allows navigation from anywhere (interceptors,
/// services, streams) without needing a BuildContext.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Widget startPage = const LoginPage();

  try {
    await Firebase.initializeApp();
    await ApiConfig.initialize();

    // Use TokenManager (which has resetOnError: true and corruption
    // detection built in) instead of raw FlutterSecureStorage.
    final tokenManager = TokenManager();

    // Proactive health check: detect and clear corrupted storage
    // BEFORE attempting to read the token.
    final wasCorrupted = await tokenManager.detectAndClearCorruption();
    if (wasCorrupted) {
      debugPrint("======== SECURE STORAGE WAS CORRUPTED ========");
      debugPrint("Storage cleared. User will need to login again.");
      debugPrint("===============================================");
      // startPage stays as LoginPage
    } else {
      // Storage is healthy — check for existing session
      final String? token = await tokenManager.getToken();
      if (token != null && token.isNotEmpty) {
        startPage = const HomeScreen();
      }
    }
  } on PlatformException catch (e) {
    // Last-resort catch for any PlatformException that slips through
    // TokenManager's internal handling (e.g., during detectAndClearCorruption
    // itself, or if deleteAll() also fails).
    debugPrint("======== PLATFORM EXCEPTION DI MAIN ========");
    debugPrint("Code: ${e.code}");
    debugPrint("Message: ${e.message}");
    debugPrint("Details: ${e.details}");
    debugPrint("Falling back to LoginPage.");
    debugPrint("============================================");
    // startPage stays as LoginPage — safest fallback
  } catch (e) {
    debugPrint("======== ERROR DI MAIN ========");
    debugPrint(e.toString());
    debugPrint("===============================");
    // startPage stays as LoginPage
  }

  // Wire the global navigator key to AuthInterceptor so it can push
  // the MaintenanceScreen route on 503 errors without a BuildContext.
  AuthInterceptor.navigatorKey = navigatorKey;

  runApp(MyApp(startPage: startPage));
}

class MyApp extends StatefulWidget {
  final Widget startPage;

  const MyApp({super.key, required this.startPage});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<void>? _logoutSubscription;

  @override
  void initState() {
    super.initState();
    _listenToLogoutEvents();
  }

  /// Subscribe to the global logout stream from TokenManager.
  ///
  /// This is the SINGLE source of truth for all logout navigation:
  /// - 401 Unauthorized (token expired) → AuthInterceptor calls triggerLogout()
  /// - Manual logout from ProfilePage → calls triggerLogout()
  /// - Account deletion from ProfilePage → calls triggerLogout()
  ///
  /// All paths converge here, guaranteeing the user is always redirected
  /// to LoginPage regardless of which screen they are on.
  void _listenToLogoutEvents() {
    _logoutSubscription = TokenManager().onLogout.listen((_) {
      developer.log(
        '⚠ Global logout event received — navigating to LoginPage',
        name: 'MyApp',
      );

      final navigator = navigatorKey.currentState;
      if (navigator != null) {
        navigator.pushNamedAndRemoveUntil(
          AppRoutes.login,
          (route) => false, // Remove ALL routes from the stack
        );
      } else {
        developer.log(
          '✗ navigatorKey.currentState is null — cannot navigate',
          name: 'MyApp',
        );
      }
    });
  }

  @override
  void dispose() {
    _logoutSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DeviceProvider(),
      child: MaterialApp(
        title: 'Kandang Pintar',
        navigatorKey: navigatorKey,
        theme: _buildLightTheme(),
        darkTheme: _buildDarkTheme(),
        themeMode: ThemeMode.light,
        
        // KUNCI PERBAIKAN TOMBOL BACK: Pakai properti 'home', BUKAN 'initialRoute'
        // OfflineBanner wraps the start page to show a persistent red banner
        // at the top of the screen when the device has no internet.
        home: OfflineBanner(child: widget.startPage),

        onGenerateRoute: AppRoutes.generateRoute,
        debugShowCheckedModeBanner: false,
      ),
    );
  }

  /// Build Light Theme dengan palet Kandang Pintar
  static ThemeData _buildLightTheme() {
    return ThemeData(
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryGreen,
        secondary: AppColors.primaryBlue,
        tertiary: AppColors.accentOrange,
        surface: AppColors.lightBackground,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onTertiary: Colors.white,
        onSurface: AppColors.textPrimary,
        onError: Colors.white,
      ),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightBackground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderLight, width: 1)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderLight, width: 1)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.error, width: 1)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.error, width: 2)),
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
        hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.7), fontSize: 14),
      ),
      scaffoldBackgroundColor: AppColors.lightBackground,
    );
  }

  static ThemeData _buildDarkTheme() {
    return ThemeData(
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryGreen,
        secondary: AppColors.primaryBlue,
        tertiary: AppColors.accentOrange,
        surface: Color(0xFF2A2A2A),
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onTertiary: Colors.white,
        onSurface: Colors.white,
        onError: Colors.white,
      ),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(backgroundColor: AppColors.darkBackground, foregroundColor: Colors.white, elevation: 0),
      scaffoldBackgroundColor: AppColors.darkBackground,
    );
  }
}