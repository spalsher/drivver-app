import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'feminine_theme.dart';

class ThemeManager {
  static ThemeData getTheme(String? gender, String? themePreference) {
    // Determine theme based on gender and preference
    if (gender == 'female' || themePreference == 'feminine') {
      return FeminineTheme.theme;
    } else {
      return AppTheme.lightTheme;
    }
  }
  
  static bool isFeminineTheme(String? gender, String? themePreference) {
    return gender == 'female' || themePreference == 'feminine';
  }
  
  static Color getPrimaryColor(String? gender, String? themePreference) {
    if (isFeminineTheme(gender, themePreference)) {
      return FeminineTheme.primaryColor;
    } else {
      return AppTheme.primaryColor;
    }
  }
  
  static List<Color> getPrimaryGradient(String? gender, String? themePreference) {
    if (isFeminineTheme(gender, themePreference)) {
      return FeminineTheme.primaryGradient;
    } else {
      return [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.8)];
    }
  }
  
  static Color getBackgroundColor(String? gender, String? themePreference) {
    if (isFeminineTheme(gender, themePreference)) {
      return FeminineTheme.backgroundLight;
    } else {
      return AppTheme.gray50;
    }
  }
}
