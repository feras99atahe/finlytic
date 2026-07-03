import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Anthropic / Claude brand identity.
class AppTheme {
  // Brand core
  static const Color dark      = Color(0xFF141413); // primary text & dark bg
  static const Color light     = Color(0xFFFAF9F5); // page bg
  static const Color midGray   = Color(0xFFB0AEA5);
  static const Color lightGray = Color(0xFFE8E6DC);

  // Accents
  static const Color orange = Color(0xFFD97757); // primary accent
  static const Color blue   = Color(0xFF6A9BCC); // secondary accent
  static const Color green  = Color(0xFF788C5D); // tertiary accent
  static const Color purple = Color(0xFF8B6BA8); // debt
  static const Color slate  = Color(0xFF5C7A89); // opening balance

  // Semantic
  static const Color positive = green;   // savings / income
  static const Color negative = orange;  // spending / loss

  // Soft tints
  static const Color orangeTint = Color(0xFFF6E4DA);
  static const Color blueTint   = Color(0xFFDFEAF4);
  static const Color greenTint  = Color(0xFFE2E8D5);
  static const Color purpleTint = Color(0xFFEBE2F2);
  static const Color slateTint  = Color(0xFFDDE6EA);

  // Category palette
  static const Map<String, Color> categoryColors = {
    'Food'        : orange,
    'Services'    : blue,
    'Restaurants' : Color(0xFFC18558),
    'Personal'    : green,
    'Debt'        : Color(0xFFA84B33),
    'Transport'   : Color(0xFF4F7AA8),
    'Shopping'    : Color(0xFFD9A557),
    'Health'      : Color(0xFF6B8E5A),
    'Entertain.'  : Color(0xFF8B6BA8),
    'Other'       : midGray,
  };

  /// Palette used to give user-added categories (no fixed color above) a
  /// stable, distinct color instead of all collapsing to grey.
  static const List<Color> _categoryPalette = [
    orange, blue, green,
    Color(0xFFC18558), Color(0xFFA84B33), Color(0xFF4F7AA8),
    Color(0xFFD9A557), Color(0xFF6B8E5A), Color(0xFF8B6BA8),
  ];

  /// Color for a category name: the fixed mapping when present, otherwise a
  /// deterministic palette color derived from the name.
  static Color colorForCategory(String name) =>
      categoryColors[name] ??
      _categoryPalette[name.hashCode.abs() % _categoryPalette.length];

  static ThemeData get lightTheme {
    final base = ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: light,
      primaryColor: dark,
      colorScheme: const ColorScheme.light(
        primary: dark,
        secondary: orange,
        error: orange,
        surface: light,
        onPrimary: light,
        onSecondary: light,
      ),
      textTheme: GoogleFonts.loraTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.poppins(
            fontSize: 48, fontWeight: FontWeight.w700, color: dark, height: 1.05, letterSpacing: -1.2),
        displayMedium: GoogleFonts.poppins(
            fontSize: 36, fontWeight: FontWeight.w700, color: dark, height: 1.05, letterSpacing: -0.8),
        displaySmall: GoogleFonts.poppins(
            fontSize: 28, fontWeight: FontWeight.w600, color: dark, letterSpacing: -0.4),
        headlineMedium: GoogleFonts.poppins(
            fontSize: 22, fontWeight: FontWeight.w600, color: dark),
        headlineSmall: GoogleFonts.poppins(
            fontSize: 18, fontWeight: FontWeight.w600, color: dark),
        titleLarge: GoogleFonts.poppins(
            fontSize: 16, fontWeight: FontWeight.w600, color: dark),
        titleMedium: GoogleFonts.poppins(
            fontSize: 14, fontWeight: FontWeight.w600, color: dark),
        bodyLarge:  GoogleFonts.lora(fontSize: 16, color: dark, height: 1.5),
        bodyMedium: GoogleFonts.lora(fontSize: 14, color: dark, height: 1.5),
        bodySmall:  GoogleFonts.lora(fontSize: 12, color: midGray),
        labelLarge: GoogleFonts.poppins(
            fontSize: 12, fontWeight: FontWeight.w600,
            letterSpacing: 1.2, color: dark),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: light,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: dark),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20, fontWeight: FontWeight.w600, color: dark,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightGray, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: dark,
          foregroundColor: light,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: dark,
          side: const BorderSide(color: dark, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: orange,
          textStyle: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightGray),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: orange, width: 1.5),
        ),
        labelStyle: GoogleFonts.lora(color: midGray, fontSize: 14),
        hintStyle: GoogleFonts.lora(color: midGray, fontSize: 14),
      ),
      dividerTheme: const DividerThemeData(
          color: lightGray, thickness: 1, space: 1),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: light,
        selectedItemColor: dark,
        unselectedItemColor: midGray,
        selectedLabelStyle: GoogleFonts.poppins(
            fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.poppins(
            fontSize: 11, fontWeight: FontWeight.w500),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: orange,
        foregroundColor: light,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: light,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18, fontWeight: FontWeight.w600, color: dark,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: lightGray,
        selectedColor: dark,
        labelStyle: GoogleFonts.poppins(
            fontSize: 12, fontWeight: FontWeight.w500, color: dark),
        secondaryLabelStyle: GoogleFonts.poppins(
            fontSize: 12, fontWeight: FontWeight.w500, color: light),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
