import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const darkSlate = Color(0xFF020617);
  static const obsidian = Color(0xFF0B0F19);
  static const cardDark = Color(0xFF0F172A);
  static const cardBorder = Color(0xFF1E293B);
  
  static const cyberIndigo = Color(0xFF6366F1);
  static const cyberCyan = Color(0xFF06B6D4);
  static const dangerRose = Color(0xFFF43F5E);
  static const successEmerald = Color(0xFF10B981);
  static const warningAmber = Color(0xFFF59E0B);
  
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFF94A3B8);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkSlate,
      primaryColor: cyberIndigo,
      colorScheme: const ColorScheme.dark(
        primary: cyberIndigo,
        secondary: cyberCyan,
        error: dangerRose,
        surface: cardDark,
      ),
      fontFamily: GoogleFonts.outfit().fontFamily,
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
        headlineLarge: GoogleFonts.outfit(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.outfit(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: GoogleFonts.outfit(
          fontSize: 15,
          color: textPrimary,
        ),
        bodyMedium: GoogleFonts.outfit(
          fontSize: 13,
          color: textSecondary,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: cardBorder, width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(cardDark),
        ),
      ),
    );
  }

  // Helper decoration for glassmorphism
  static BoxDecoration glassDecoration({
    Color color = const Color(0x0F1E293B),
    double blur = 10,
    double borderRadius = 16,
    Color borderColor = cardBorder,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderColor, width: 1.5),
    );
  }

  // Terminal box styling
  static BoxDecoration terminalDecoration() {
    return BoxDecoration(
      color: const Color(0xFF05070C),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
    );
  }
}
