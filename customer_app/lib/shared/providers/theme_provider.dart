import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../themes/theme_manager.dart';
import '../../core/services/user_service.dart';

class ThemeNotifier extends StateNotifier<ThemeData> {
  ThemeNotifier() : super(ThemeManager.getTheme(null, null)) {
    _loadUserTheme();
  }
  
  String? _currentGender;
  String? _currentThemePreference;
  
  String? get currentGender => _currentGender;
  String? get currentThemePreference => _currentThemePreference;
  
  Future<void> _loadUserTheme() async {
    try {
      final profile = await UserService.getUserProfile();
      if (profile != null && profile['user'] != null) {
        final user = profile['user'];
        _currentGender = user['gender'];
        _currentThemePreference = user['theme_preference'];
        
        // Update theme based on user's gender and preference
        state = ThemeManager.getTheme(_currentGender, _currentThemePreference);
        
        print('🎨 Theme updated for gender: $_currentGender, preference: $_currentThemePreference');
      }
    } catch (e) {
      print('❌ Error loading user theme: $e');
    }
  }
  
  void updateTheme(String? gender, String? themePreference) {
    _currentGender = gender;
    _currentThemePreference = themePreference;
    state = ThemeManager.getTheme(gender, themePreference);
    
    print('🎨 Theme manually updated for gender: $gender, preference: $themePreference');
  }
  
  void refreshTheme() {
    _loadUserTheme();
  }
  
  bool get isFeminineTheme {
    return ThemeManager.isFeminineTheme(_currentGender, _currentThemePreference);
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeData>((ref) {
  return ThemeNotifier();
});
