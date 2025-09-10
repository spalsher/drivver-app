import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'core/constants/app_constants.dart';
import 'shared/themes/app_theme.dart';
import 'shared/providers/theme_provider.dart';
import 'core/services/navigation_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(
    const ProviderScope(
      child: DrivrrCustomerApp(),
    ),
  );
}

class DrivrrCustomerApp extends ConsumerWidget {
  const DrivrrCustomerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeProvider);
    
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      
      // Dynamic theme based on user gender
      theme: currentTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light, // Always use light mode for now
      
      // Router configuration
      routerConfig: NavigationService.router,
      
      // Global configurations
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0), // Prevent system font scaling
          ),
          child: child!,
        );
      },
      
      // Localization support (future enhancement)
      locale: const Locale('en', 'US'),
      supportedLocales: const [
        Locale('en', 'US'),
        // Add more locales as needed
      ],
    );
  }
}