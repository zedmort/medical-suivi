import 'package:flutter/material.dart';

class MediGoTheme {
  static const Color primaryBlue = Color(0xFF1B62E8);
  static const Color deepBlueStart = Color(0xFF0B2F8F);
  static const Color deepBlueEnd = Color(0xFF1A56D6);
  static const Color backgroundStart = Color(0xFFF4F8FF);
  static const Color backgroundEnd = Color(0xFFE6EFFF);
  static const Color heartRed = Color(0xFFE5232E);
  static const Color successGreen = Color(0xFF1E8E5A);
  static const Color warningOrange = Color(0xFFE8890C);
  static const Color pharmacyGreenStart = Color(0xFF0E7C54);
  static const Color pharmacyGreenEnd = Color(0xFF1A9B6A);
  static const Color darkNavy = Color(0xFF0B1B3F);
  static const Color secondaryGrey = Color(0xFF6B7A99);
  static const Color borderSoft = Color(0xFFE9EEF9);
  static const Color cardBorder = Color(0xFFE5EAF5);
  static const Color cardSurface = Colors.white;
  static const Color orangeChipBg = Color(0xFFFDEBD3);
  static const Color orangeChipText = warningOrange;
  static const Color greenChipBg = Color(0xFFDDF3E6);
  static const Color greenChipText = successGreen;

  static const double cardRadius = 16;
  static const double pillRadius = 24;
  static const String fontFamily = 'Poppins';

  static ThemeData buildTheme() {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: backgroundStart,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        primary: primaryBlue,
        secondary: deepBlueEnd,
        surface: cardSurface,
        brightness: Brightness.light,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w800,
          color: darkNavy,
          letterSpacing: -0.7,
        ),
        headlineMedium: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          color: darkNavy,
          letterSpacing: -0.4,
        ),
        titleLarge: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          color: darkNavy,
        ),
        titleMedium: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w600,
          color: darkNavy,
        ),
        bodyMedium: TextStyle(fontFamily: fontFamily, color: secondaryGrey),
        bodySmall: TextStyle(fontFamily: fontFamily, color: secondaryGrey),
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: cardBorder),
        ),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: darkNavy,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        hintStyle: const TextStyle(
          fontFamily: fontFamily,
          color: Color(0xFF94A1BF),
        ),
        labelStyle: const TextStyle(
          fontFamily: fontFamily,
          color: secondaryGrey,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: borderSoft),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: borderSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: primaryBlue, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: backgroundStart,
      canvasColor: Colors.white,
      dividerColor: borderSoft,
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
    );
  }
}
