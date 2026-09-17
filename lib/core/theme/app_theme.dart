import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized app theme — dark-first IPTV aesthetic with
/// a deep charcoal + True Red (#FF0000) accent palette.
class AppTheme {
  AppTheme._();

  // ── Color palette ──────────────────────────────────────────────
  static const Color _primary = Color(0xFFFF0000);     // True Red
  static const Color _primaryDark = Color(0xFF9B0000);
  static const Color _accent = Color(0xFFFF5C5C);      // Soft red accent
  static const Color _background = Color(0xFF140D0D);  // Deep warm black
  static const Color _surface = Color(0xFF1E1515);      // Card surface
  static const Color _surfaceVariant = Color(0xFF2A1B1B);
  static const Color _error = Color(0xFFFF5252);
  static const Color _onBackground = Color(0xFFE8ECF4);
  static const Color _onSurface = Color(0xFFC0C8D8);
  static const Color _muted = Color(0xFF6B7588);

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      colorScheme: const ColorScheme.dark(
        primary: _primary,
        secondary: _accent,
        surface: _surface,
        error: _error,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: _onSurface,
        onBackground: _onBackground,
      ),
      scaffoldBackgroundColor: _background,
      appBarTheme: AppBarTheme(
        backgroundColor: _background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _onBackground,
        ),
        iconTheme: const IconThemeData(color: _onBackground),
      ),
      cardTheme: CardThemeData(
        color: _surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _error, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: const TextStyle(color: _muted),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _surface,
        selectedItemColor: _primary,
        unselectedItemColor: _muted,
        type: BottomNavigationBarType.fixed,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        headlineLarge: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: _onBackground,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: _onBackground,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          color: _onBackground,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          color: _onSurface,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          color: _muted,
        ),
      ),
    );
  }
}
