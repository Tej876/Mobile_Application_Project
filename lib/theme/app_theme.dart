import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // User Pinned Palette: Blush • Peach • Nude • Plum • Maroon • Charcoal
  static const Color blush = Color(0xFFF6E7E2); // Swatch 1: Blush
  static const Color peach = Color(0xFFE6CFC8); // Swatch 2: Peach
  static const Color nude = Color(0xFFBF9B8E); // Swatch 3: Nude
  static const Color plum = Color(0xFF7E6570); // Swatch 4: Plum
  static const Color maroon = Color(0xFF593E47); // Swatch 5: Maroon
  static const Color charcoal = Color(0xFF33252B); // Swatch 6: Charcoal

  // Semantic Role Tokens mapped from the 6 swatches
  static const Color primaryColor = maroon; // #593E47 Maroon
  static const Color primaryDark = charcoal; // #33252B Charcoal
  static const Color accentColor = nude; // #BF9B8E Nude
  static const Color backgroundColor = blush; // #F6E7E2 Blush canvas
  static const Color surfaceColor = Color(0xFFFFFBFA); // Warm blush-porcelain card surface
  static const Color surfaceMuted = peach; // #E6CFC8 Peach track/pill surface
  static const Color borderColor = Color(0xFFDCC2BA); // Crisp 1px Peach-Nude border
  static const Color textPrimary = charcoal; // #33252B Charcoal primary ink
  static const Color textSecondary = Color(0xFF6B535D); // Deepened Plum for >=4.5:1 AA contrast
  static const Color errorColor = Color(0xFF9E2A3B); // Deep Berry Crimson
  static const Color successColor = Color(0xFF2E6F54); // Muted Botanical Sage-Emerald

  static TextStyle monoStyle({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    double letterSpacing = 0.4,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? textPrimary,
      letterSpacing: letterSpacing,
    );
  }

  static ThemeData get lightTheme {
    final baseText = GoogleFonts.plusJakartaSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: accentColor,
        surface: surfaceColor,
        error: errorColor,
        onPrimary: Colors.white,
        onSurface: textPrimary,
      ),
      dividerColor: borderColor,
      textTheme: baseText.copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(
          color: textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 32,
          letterSpacing: -0.8,
          height: 1.15,
        ),
        displayMedium: GoogleFonts.plusJakartaSans(
          color: textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 26,
          letterSpacing: -0.6,
          height: 1.2,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          color: textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 19,
          letterSpacing: -0.3,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          color: textPrimary,
          fontSize: 15,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          color: textSecondary,
          fontSize: 14,
          height: 1.45,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 22),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: -0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: borderColor, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderColor, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryColor, width: 1.8),
        ),
        hintStyle: GoogleFonts.plusJakartaSans(
          color: const Color(0xFF949B97),
          fontSize: 14,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: borderColor, width: 1),
        ),
      ),
    );
  }
}

