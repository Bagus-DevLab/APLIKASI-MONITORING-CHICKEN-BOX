import 'package:flutter/material.dart';

class AppColors {
  // ============ PRIMARY COLORS ============
  /// Hijau Pertanian - Represents agriculture, nature, and trust
  static const Color primaryGreen = Color(0xFF2E7D32);
  
  /// Biru IoT - Represents technology, smart systems, and connectivity
  static const Color primaryBlue = Color(0xFF1976D2);
  
  /// Orange Accent - Represents energy, warmth, and poultry farming
  static const Color accentOrange = Color(0xFFFFA500);

  // ============ BACKGROUND COLORS ============
  /// Dark brown background for header (sesuai desain)
  static const Color darkBrown = Color(0xFF4A3728);
  
  /// Light background for content areas
  static const Color lightBackground = Color(0xFFE8E8E8);
  
  /// Secondary light background (white cards)
  static const Color secondaryLight = Color(0xFFFFFFFF);

  // ============ TEXT COLORS ============
  /// Primary text color (dark gray/brown)
  static const Color textPrimary = Color(0xFF2D2D2D);
  
  /// Secondary text color (medium gray)
  static const Color textSecondary = Color(0xFF666666);
  
  /// Tertiary text color (light gray)
  static const Color textTertiary = Color(0xFF999999);
  
  /// Text color for dark backgrounds
  static const Color textLight = Color(0xFFFFFFFF);

  // ============ STATUS COLORS ============
  /// Normal status - Green
  static const Color statusNormal = Color(0xFF4CAF50);
  
  /// Warning status - Orange/Amber
  static const Color statusWarning = Color(0xFFFF9800);
  
  /// Alert/Error status - Red
  static const Color statusAlert = Color(0xFFF44336);
  
  /// Info status - Light Orange
  static const Color statusInfo = Color(0xFFFFA500);

  // ============ BORDER & DIVIDER ============
  /// Light gray border
  static const Color borderLight = Color(0xFFD9D9D9);
  
  /// Dark gray border
  static const Color borderDark = Color(0xFF424242);

  // ============ ERROR & SPECIAL COLORS ============
  /// Error color
  static const Color error = statusAlert;
  
  /// Dark background color (for header)
  static const Color darkBackground = darkBrown;

  // ============ SHADOW COLORS ============
  static Color shadowColor = Colors.black.withValues(alpha: 0.1);
  static Color shadowColorDark = Colors.black.withValues(alpha: 0.15);

  // ============ GRADIENT COMBINATIONS ============
  /// Brown to Green gradient (untuk header)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [darkBrown, Color(0xFF6B5344)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Green gradient
  static const LinearGradient greenGradient = LinearGradient(
    colors: [primaryGreen, Color(0xFF1B5E20)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Blue gradient
  static const LinearGradient blueGradient = LinearGradient(
    colors: [primaryBlue, Color(0xFF0D47A1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Material Color Scheme for Kandang Pintar
/// Use this in your MaterialApp theme
class AppColorScheme {
  static ColorScheme lightColorScheme = const ColorScheme.light(
    primary: AppColors.primaryGreen,
    secondary: AppColors.accentOrange,
    tertiary: AppColors.primaryBlue,
    surface: AppColors.secondaryLight,
    error: AppColors.statusAlert,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onTertiary: Colors.white,
    onSurface: AppColors.textPrimary,
    onError: Colors.white,
  );

  static ColorScheme darkColorScheme = const ColorScheme.dark(
    primary: AppColors.primaryGreen,
    secondary: AppColors.accentOrange,
    tertiary: AppColors.primaryBlue,
    surface: Color(0xFF3A3A3A),
    error: AppColors.statusAlert,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onTertiary: Colors.white,
    onSurface: Colors.white,
    onError: Colors.white,
  );

  static ThemeData buildDarkTheme() {
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
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
    );
  }
}