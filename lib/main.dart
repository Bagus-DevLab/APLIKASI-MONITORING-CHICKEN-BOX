import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'constants/app_colors.dart';
import 'routes/app_routes.dart';
import 'package:firebase_core/firebase_core.dart';
import 'constants/api_config.dart';
import 'core/network/token_manager.dart';

import 'pages/login_page.dart';
import 'pages/home_screen.dart';

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

  runApp(MyApp(startPage: startPage));
}

class MyApp extends StatelessWidget {
  final Widget startPage;

  const MyApp({super.key, required this.startPage});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kandang Pintar',
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: ThemeMode.light,
      
      // KUNCI PERBAIKAN TOMBOL BACK: Pakai properti 'home', BUKAN 'initialRoute'
      home: startPage,

      onGenerateRoute: AppRoutes.generateRoute,
      debugShowCheckedModeBanner: false,
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