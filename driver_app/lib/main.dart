import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/navigation_service.dart';
import 'shared/themes/app_theme.dart';

void main() {
  runApp(
    const ProviderScope(
      child: DrivrrDriverApp(),
    ),
  );
}

class DrivrrDriverApp extends StatelessWidget {
  const DrivrrDriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Drivrr Driver',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: NavigationService.router,
    );
  }
}