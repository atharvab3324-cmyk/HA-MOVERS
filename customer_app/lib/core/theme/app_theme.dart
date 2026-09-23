import 'package:flutter/material.dart';

class AppColors {
  // Brand
  static const Color primaryBlue = Color(0xFF1769E0);
  static const Color deepBlue = Color(0xFF0D47A1);
  static const Color secondaryCyan = Color(0xFF00B8D9);
  static const Color lightBlue = Color(0xFFE8F1FF);

  // Surfaces
  static const Color white = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF5F7FA);

  // Text
  static const Color primaryText = Color(0xFF172033);
  static const Color secondaryText = Color(0xFF667085);

  // UI
  static const Color border = Color(0xFFE4E7EC);

  // Status
  static const Color success = Color(0xFF12B76A);
  static const Color warning = Color(0xFFF79009);
  static const Color error = Color(0xFFF04438);
  static const Color disabled = Color(0xFF98A2B3);
}

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,

    scaffoldBackgroundColor: AppColors.background,

    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryBlue,
      primary: AppColors.primaryBlue,
      secondary: AppColors.secondaryCyan,
      surface: AppColors.white,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.primaryText,
      elevation: 0,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: AppColors.primaryBlue, width: 2),
      ),
    ),
  );
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,

    scaffoldBackgroundColor: const Color(0xFF0D1B2A),

    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryBlue,
      brightness: Brightness.dark,
      primary: AppColors.primaryBlue,
      secondary: AppColors.secondaryCyan,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0D1B2A),
      foregroundColor: AppColors.white,
      elevation: 0,
    ),
  );
}
