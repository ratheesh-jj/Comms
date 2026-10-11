import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Dark theme colors
  static const Color black = Color(0xFF000000);
  static const Color darkGrey = Color(0xFF1F1F1F);
  static const Color activityGrey = Color(0xFF2C2C2C);
  static const Color mediumGrey = Color(0xFF7A7A7A);
  static const Color lightGrey = Color(0xFFE6E6E6);
  static const Color white = Color(0xFFFFFFFF);

  // Deep blue theme colors (VS Code style)
  static const Color deepNavy = Color(0xFF181825); // Main background
  static const Color darkBlue = Color(0xFF1F1F2E); // Surface/cards
  static const Color accentBlue = Color(0xFF5090F0); // Primary accent
  static const Color lightBlue = Color(0xFF6AA5F5); // Secondary accent

  // Gradient colors for dark theme
  static const Color darkGradientStart = Color(0xFF0D0D0D);
  static const Color darkGradientEnd = Color(0xFF1A1A2E);

  // Gradient colors for deep blue theme
  static const Color blueGradientStart = Color(0xFF0F0F1A);
  static const Color blueGradientEnd = Color(0xFF1A1A3E);
}

class AppTheme {
  static TextTheme _buildTextTheme(TextTheme base) {
    return GoogleFonts.firaSansTextTheme(base).copyWith(
      displayLarge: GoogleFonts.firaSans(
        textStyle: base.displayLarge,
        fontWeight: FontWeight.w800,
      ),
      displayMedium: GoogleFonts.firaSans(
        textStyle: base.displayMedium,
        fontWeight: FontWeight.w800,
      ),
      displaySmall: GoogleFonts.firaSans(
        textStyle: base.displaySmall,
        fontWeight: FontWeight.w800,
      ),
      headlineLarge: GoogleFonts.firaSans(
        textStyle: base.headlineLarge,
        fontWeight: FontWeight.w800,
      ),
      headlineMedium: GoogleFonts.firaSans(
        textStyle: base.headlineMedium,
        fontWeight: FontWeight.w800,
      ),
      headlineSmall: GoogleFonts.firaSans(
        textStyle: base.headlineSmall,
        fontWeight: FontWeight.w800,
      ),
      titleLarge: GoogleFonts.firaSans(
        textStyle: base.titleLarge,
        fontWeight: FontWeight.w800,
      ),
      titleMedium: GoogleFonts.firaSans(
        textStyle: base.titleMedium,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.black,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.white,
        onPrimary: AppColors.black,
        secondary: AppColors.mediumGrey,
        onSecondary: AppColors.white,
        surface: AppColors.darkGrey,
        onSurface: AppColors.white,
      ),
      textTheme: _buildTextTheme(
        ThemeData(brightness: Brightness.dark).textTheme,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: const Size(44, 44),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.white,
          side: const BorderSide(color: AppColors.white, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: const Size(44, 44),
        ),
      ),
    );
  }

  static ThemeData get deepBlueTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.deepNavy,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accentBlue,
        onPrimary: AppColors.deepNavy,
        secondary: AppColors.lightBlue,
        onSecondary: AppColors.deepNavy,
        surface: AppColors.darkBlue,
        onSurface: AppColors.white,
      ),
      textTheme: _buildTextTheme(
        ThemeData(brightness: Brightness.dark).textTheme,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.deepNavy,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentBlue,
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: const Size(44, 44),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accentBlue,
          side: const BorderSide(color: AppColors.accentBlue, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: const Size(44, 44),
        ),
      ),
    );
  }

  // Gradient for dark theme
  static LinearGradient get darkGradient {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppColors.darkGradientStart, AppColors.darkGradientEnd],
    );
  }

  // Gradient for deep blue theme
  static LinearGradient get deepBlueGradient {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppColors.blueGradientStart, AppColors.blueGradientEnd],
    );
  }
}
