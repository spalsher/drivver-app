import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FeminineTheme {
  // Feminine color palette - soft pinks, purples, and warm tones
  static const Color primaryColor = Color(0xFFE91E63); // Pink
  static const Color primaryVariant = Color(0xFFC2185B); // Darker pink
  static const Color secondaryColor = Color(0xFF9C27B0); // Purple
  static const Color secondaryVariant = Color(0xFF7B1FA2); // Darker purple
  static const Color accentColor = Color(0xFFFF4081); // Bright pink accent
  
  // Soft pastel colors for backgrounds
  static const Color backgroundLight = Color(0xFFFCE4EC); // Light pink
  static const Color surfaceLight = Color(0xFFF8BBD9); // Soft pink
  static const Color cardBackground = Color(0xFFFFF0F3); // Very light pink
  
  // Safety-focused colors
  static const Color safetyGreen = Color(0xFF4CAF50);
  static const Color warningAmber = Color(0xFFFF9800);
  static const Color alertRed = Color(0xFFE53935);
  
  // Text colors
  static const Color textPrimary = Color(0xFF2E2E2E);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textOnPrimary = Colors.white;
  
  // Gradient colors
  static const List<Color> primaryGradient = [
    Color(0xFFE91E63),
    Color(0xFF9C27B0),
  ];
  
  static const List<Color> softGradient = [
    Color(0xFFFCE4EC),
    Color(0xFFF3E5F5),
  ];

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      
      // Color scheme
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        primaryContainer: backgroundLight,
        secondary: secondaryColor,
        secondaryContainer: surfaceLight,
        surface: cardBackground,
        background: backgroundLight,
        error: alertRed,
        onPrimary: textOnPrimary,
        onSecondary: textOnPrimary,
        onSurface: textPrimary,
        onBackground: textPrimary,
      ),
      
      // Typography with feminine feel
      textTheme: GoogleFonts.poppinsTextTheme().copyWith(
        displayLarge: GoogleFonts.poppins(
          fontSize: 32,
          fontWeight: FontWeight.w300,
          color: textPrimary,
          letterSpacing: -1.5,
        ),
        displayMedium: GoogleFonts.poppins(
          fontSize: 28,
          fontWeight: FontWeight.w300,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        headlineLarge: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          letterSpacing: 0.15,
        ),
        titleLarge: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          letterSpacing: 0.15,
        ),
        bodyLarge: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          letterSpacing: 0.5,
        ),
        bodyMedium: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          letterSpacing: 0.25,
        ),
      ),
      
      // App bar theme with feminine styling
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      
      // Card theme with soft rounded corners
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 8,
        shadowColor: primaryColor.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      
      // Elevated button theme with feminine gradient
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: textOnPrimary,
          elevation: 8,
          shadowColor: primaryColor.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      
      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primaryColor.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primaryColor.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        labelStyle: GoogleFonts.poppins(
          color: textSecondary,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: GoogleFonts.poppins(
          color: textSecondary.withOpacity(0.7),
        ),
      ),
      
      // Bottom navigation theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardBackground,
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondary,
        elevation: 20,
        type: BottomNavigationBarType.fixed,
      ),
      
      // Floating action button theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: textOnPrimary,
        elevation: 12,
      ),
      
      // Scaffold background
      scaffoldBackgroundColor: backgroundLight,
    );
  }
}
