import 'package:flutter/material.dart';

enum ThemeType {
  darkViolet,
  amoled,
  light,
}

class AppTheme {
  // Brand Violet Colors
  static const Color primaryViolet = Color(0xFF8B5CF6);
  static const Color primaryVioletDark = Color(0xFF6D28D9);
  static const Color primaryVioletLight = Color(0xFFA78BFA);
  static const Color accentNeon = Color(0xFFEC4899);
  static const Color cyanGlow = Color(0xFF06B6D4);
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color dangerRed = Color(0xFFEF4444);

  // Dark Violet Palette
  static const Color darkBg = Color(0xFF0B0B14);
  static const Color darkCard = Color(0xFF131326);
  static const Color darkCardBorder = Color(0xFF222245);
  static const Color darkInputBg = Color(0xFF171730);

  // AMOLED True Black Palette
  static const Color amoledBg = Color(0xFF000000);
  static const Color amoledCard = Color(0xFF0D0D0D);
  static const Color amoledCardBorder = Color(0xFF1F1F1F);
  static const Color amoledInputBg = Color(0xFF121212);

  // Light Palette
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightCardBorder = Color(0xFFE2E8F0);
  static const Color lightInputBg = Color(0xFFF1F5F9);

  static ThemeData getTheme(ThemeType type) {
    switch (type) {
      case ThemeType.amoled:
        return _buildTheme(
          brightness: Brightness.dark,
          bg: amoledBg,
          card: amoledCard,
          border: amoledCardBorder,
          input: amoledInputBg,
          textPrimary: Colors.white,
          textSecondary: Color(0xFF94A3B8),
        );
      case ThemeType.light:
        return _buildTheme(
          brightness: Brightness.light,
          bg: lightBg,
          card: lightCard,
          border: lightCardBorder,
          input: lightInputBg,
          textPrimary: Color(0xFF0F172A),
          textSecondary: Color(0xFF64748B),
        );
      case ThemeType.darkViolet:
      default:
        return _buildTheme(
          brightness: Brightness.dark,
          bg: darkBg,
          card: darkCard,
          border: darkCardBorder,
          input: darkInputBg,
          textPrimary: Colors.white,
          textSecondary: Color(0xFF94A3B8),
        );
    }
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color bg,
    required Color card,
    required Color border,
    required Color input,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      primaryColor: primaryViolet,
      cardColor: card,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primaryViolet,
        onPrimary: Colors.white,
        secondary: accentNeon,
        onSecondary: Colors.white,
        error: dangerRed,
        onError: Colors.white,
        surface: card,
        onSurface: textPrimary,
      ),
      cardTheme: CardTheme(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: input,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primaryViolet, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: bg,
        selectedItemColor: primaryViolet,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryViolet,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
      fontFamily: 'Segoe UI',
    );
  }
}
