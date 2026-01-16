import 'package:flutter/material.dart';

class AppTheme {
  /// Clean, minimal background color for light theme
  static const Color lightBackground = Color(0xFFFAFAFA);

  /// Clean, minimal background color for dark theme
  static const Color darkBackground = Color(0xFF121212);

  /// Accent gradient for visual interest (used sparingly)
  static const lightAccentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFE8F5E9),
      Color(0xFFFFFDE7),
    ],
  );

  /// Accent gradient for dark theme
  static const darkAccentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1B5E20),
      Color(0xFF33691E),
    ],
  );

  static ThemeData get lightTheme {
    const colorScheme = ColorScheme.light(
      primary: Color(0xFFD32F2F),
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFFFCDD2),
      onPrimaryContainer: Color(0xFF7F0000),
      secondary: Color(0xFF1976D2),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFBBDEFB),
      onSecondaryContainer: Color(0xFF004A77),
      surface: Color(0xFFFAFAFA),
      onSurface: Color(0xFF1A1A1A),
      surfaceContainerHighest: Color(0xFFE8E8E8),
      surfaceTint: Colors.transparent,
      error: Color(0xFFB71C1C),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: lightBackground,
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.primary,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colorScheme.onPrimary,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: colorScheme.onPrimary,
        ),
        iconTheme: IconThemeData(color: colorScheme.onPrimary),
      ),
    );
  }

  static ThemeData get darkTheme {
    const colorScheme = ColorScheme.dark(
      primary: Color(0xFFEF5350),
      onPrimary: Color(0xFF1A1A1A),
      primaryContainer: Color(0xFF7F0000),
      onPrimaryContainer: Color(0xFFFFCDD2),
      secondary: Color(0xFF64B5F6),
      onSecondary: Color(0xFF1A1A1A),
      secondaryContainer: Color(0xFF004A77),
      onSecondaryContainer: Color(0xFFBBDEFB),
      surface: Color(0xFF121212),
      onSurface: Color(0xFFE8E8E8),
      surfaceContainerHighest: Color(0xFF2A2A2A),
      surfaceTint: Colors.transparent,
      error: Color(0xFFEF5350),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkBackground,
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: const Color(0xFF1E1E1E),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.primary,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colorScheme.onPrimary,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: colorScheme.onPrimary,
        ),
        iconTheme: IconThemeData(color: colorScheme.onPrimary),
      ),
    );
  }
}

