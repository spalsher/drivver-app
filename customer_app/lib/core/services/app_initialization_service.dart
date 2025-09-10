import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'permission_service.dart';
import 'location_service.dart';
import '../constants/app_constants.dart';

class AppInitializationService {
  static final AppInitializationService _instance = AppInitializationService._internal();
  factory AppInitializationService() => _instance;
  AppInitializationService._internal();

  final PermissionService _permissionService = PermissionService();
  final LocationService _locationService = LocationService();

  /// Initialize the app with necessary permissions and services
  Future<AppInitializationResult> initializeApp(BuildContext context) async {
    try {
      // Step 1: Check if this is first launch
      bool isFirstLaunch = await _isFirstLaunch();
      
      // Step 2: Initialize essential services
      bool locationServiceEnabled = await _locationService.isLocationServiceEnabled();
      
      // Step 3: Check permissions (don't request yet, just check)
      bool hasLocationPermission = await _permissionService.isLocationPermissionGranted();
      bool hasNotificationPermission = await _permissionService.isNotificationPermissionGranted();
      
      return AppInitializationResult(
        isFirstLaunch: isFirstLaunch,
        locationServiceEnabled: locationServiceEnabled,
        hasLocationPermission: hasLocationPermission,
        hasNotificationPermission: hasNotificationPermission,
        isSuccess: true,
      );
      
    } catch (e) {
      return AppInitializationResult(
        isFirstLaunch: true,
        locationServiceEnabled: false,
        hasLocationPermission: false,
        hasNotificationPermission: false,
        isSuccess: false,
        error: e.toString(),
      );
    }
  }

  /// Request essential permissions during onboarding
  Future<PermissionRequestResult> requestEssentialPermissions(BuildContext context) async {
    final results = <String, bool>{};
    
    try {
      // Request location permission
      results['location'] = await _permissionService.handleLocationPermission(context);
      
      // Request notification permission (optional)
      results['notification'] = await _permissionService.handleNotificationPermission(context);
      
      return PermissionRequestResult(
        permissions: results,
        allGranted: results.values.every((granted) => granted),
        essentialGranted: results['location'] == true,
      );
      
    } catch (e) {
      return PermissionRequestResult(
        permissions: results,
        allGranted: false,
        essentialGranted: false,
        error: e.toString(),
      );
    }
  }

  /// Check if this is the first app launch
  Future<bool> _isFirstLaunch() async {
    // TODO: Implement with SharedPreferences
    // For now, return true to always show onboarding
    return true;
  }

  /// Mark onboarding as completed
  Future<void> markOnboardingCompleted() async {
    // TODO: Implement with SharedPreferences
    // Save that user has completed onboarding
  }

  /// Get current app state for navigation decisions
  Future<AppState> getAppState() async {
    try {
      final initResult = await initializeApp(
        // Note: This is a bit of a hack - in real app, pass context properly
        NavigationService.router.routerDelegate.navigatorKey.currentContext!,
      );
      
      if (!initResult.isSuccess) {
        return AppState.error;
      }
      
      if (initResult.isFirstLaunch) {
        return AppState.onboarding;
      }
      
      if (!initResult.hasLocationPermission) {
        return AppState.needsPermissions;
      }
      
      // TODO: Check if user is authenticated
      bool isAuthenticated = false; // await _checkAuthentication();
      
      if (!isAuthenticated) {
        return AppState.needsAuth;
      }
      
      return AppState.ready;
      
    } catch (e) {
      return AppState.error;
    }
  }
}

/// App initialization result
class AppInitializationResult {
  final bool isFirstLaunch;
  final bool locationServiceEnabled;
  final bool hasLocationPermission;
  final bool hasNotificationPermission;
  final bool isSuccess;
  final String? error;

  AppInitializationResult({
    required this.isFirstLaunch,
    required this.locationServiceEnabled,
    required this.hasLocationPermission,
    required this.hasNotificationPermission,
    required this.isSuccess,
    this.error,
  });
}

/// Permission request result
class PermissionRequestResult {
  final Map<String, bool> permissions;
  final bool allGranted;
  final bool essentialGranted;
  final String? error;

  PermissionRequestResult({
    required this.permissions,
    required this.allGranted,
    required this.essentialGranted,
    this.error,
  });
}

/// App state enum for navigation
enum AppState {
  loading,
  onboarding,
  needsPermissions,
  needsAuth,
  ready,
  error,
}

// Placeholder for NavigationService (to avoid circular imports)
class NavigationService {
  static final router = _MockRouter();
}

class _MockRouter {
  final routerDelegate = _MockDelegate();
}

class _MockDelegate {
  final navigatorKey = GlobalKey<NavigatorState>();
}
