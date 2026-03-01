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
  /// Dark background for modern UI
  static const Color darkBackground = Color(0xFF1A1A1A);
  
  /// Light background for content areas
  static const Color lightBackground = Color(0xFFF5F5F5);
  
  /// Secondary light background
  static const Color secondaryLight = Color(0xFFFAFAFA);

  // ============ TEXT COLORS ============
  /// Primary text color (dark gray)
  static const Color textPrimary = Color(0xFF212121);
  
  /// Secondary text color (medium gray)
  static const Color textSecondary = Color(0xFF666666);
  
  /// Tertiary text color (light gray)
  static const Color textTertiary = Color(0xFF999999);
  
  /// Text color for light backgrounds
  static const Color textLight = Color(0xFFFFFFFF);

  // ============ SEMANTIC COLORS ============
  /// Success state - Green
  static const Color success = Color(0xFF4CAF50);
  
  /// Warning state - Amber
  static const Color warning = Color(0xFFFFC107);
  
  /// Error state - Red
  static const Color error = Color(0xFFF44336);
  
  /// Info state - Blue
  static const Color info = Color(0xFF2196F3);

  // ============ BORDER & DIVIDER ============
  /// Light gray border
  static const Color borderLight = Color(0xFFE0E0E0);
  
  /// Dark gray border
  static const Color borderDark = Color(0xFF424242);

  // ============ SHADOW COLORS ============
  static Color shadowColor = Colors.black.withOpacity(0.1);
  static Color shadowColorDark = Colors.black.withOpacity(0.2);

  // ============ GRADIENT COMBINATIONS ============
  /// Green to Blue gradient (Agriculture to IoT)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryGreen, primaryBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Blue to Green gradient (IoT to Agriculture)
  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [primaryBlue, primaryGreen],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Full spectrum gradient (Agriculture, IoT, Energy)
  static const LinearGradient fullSpectrum = LinearGradient(
    colors: [primaryGreen, primaryBlue, accentOrange],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Material Color Scheme for Kandang Pintar
/// Use this in your MaterialApp theme
class AppColorScheme {
  static ColorScheme lightColorScheme = ColorScheme.light(
    primary: AppColors.primaryGreen,
    secondary: AppColors.primaryBlue,
    tertiary: AppColors.accentOrange,
    background: AppColors.lightBackground,
    surface: AppColors.secondaryLight,
    error: AppColors.error,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onTertiary: Colors.white,
    onBackground: AppColors.textPrimary,
    onSurface: AppColors.textPrimary,
    onError: Colors.white,
  );

  static ColorScheme darkColorScheme = ColorScheme.dark(
    primary: AppColors.primaryGreen,
    secondary: AppColors.primaryBlue,
    tertiary: AppColors.accentOrange,
    background: AppColors.darkBackground,
    surface: Color(0xFF2A2A2A),
    error: AppColors.error,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onTertiary: Colors.white,
    onBackground: AppColors.lightBackground,
    onSurface: AppColors.lightBackground,
    onError: Colors.white,
  );
}