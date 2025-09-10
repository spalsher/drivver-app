import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  /// Check if location permission is granted
  Future<bool> isLocationPermissionGranted() async {
    final status = await Permission.location.status;
    return status == PermissionStatus.granted;
  }

  /// Request location permission with rationale
  Future<PermissionStatus> requestLocationPermission() async {
    final status = await Permission.location.status;
    
    if (status == PermissionStatus.denied) {
      final result = await Permission.location.request();
      return result;
    }
    
    return status;
  }

  /// Check if notification permission is granted
  Future<bool> isNotificationPermissionGranted() async {
    final status = await Permission.notification.status;
    return status == PermissionStatus.granted;
  }

  /// Request notification permission
  Future<PermissionStatus> requestNotificationPermission() async {
    final status = await Permission.notification.status;
    
    if (status == PermissionStatus.denied) {
      final result = await Permission.notification.request();
      return result;
    }
    
    return status;
  }

  /// Check if camera permission is granted (for profile photos)
  Future<bool> isCameraPermissionGranted() async {
    final status = await Permission.camera.status;
    return status == PermissionStatus.granted;
  }

  /// Request camera permission
  Future<PermissionStatus> requestCameraPermission() async {
    final status = await Permission.camera.status;
    
    if (status == PermissionStatus.denied) {
      final result = await Permission.camera.request();
      return result;
    }
    
    return status;
  }

  /// Check if storage permission is granted
  Future<bool> isStoragePermissionGranted() async {
    final status = await Permission.storage.status;
    return status == PermissionStatus.granted;
  }

  /// Request storage permission
  Future<PermissionStatus> requestStoragePermission() async {
    final status = await Permission.storage.status;
    
    if (status == PermissionStatus.denied) {
      final result = await Permission.storage.request();
      return result;
    }
    
    return status;
  }

  /// Show permission rationale dialog
  Future<bool> showPermissionRationale(
    BuildContext context, {
    required String title,
    required String message,
    required String permission,
  }) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Allow'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  /// Show settings dialog when permission is permanently denied
  Future<bool> showSettingsDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permission Required'),
          content: const Text(
            'This permission is required for the app to function properly. '
            'Please enable it in the app settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(true);
                await openAppSettings();
              },
              child: const Text('Settings'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  /// Handle location permission flow
  Future<bool> handleLocationPermission(BuildContext context) async {
    final status = await Permission.location.status;
    
    switch (status) {
      case PermissionStatus.granted:
        return true;
        
      case PermissionStatus.denied:
        final shouldRequest = await showPermissionRationale(
          context,
          title: 'Location Permission',
          message: 'Drivrr needs access to your location to show nearby drivers and provide accurate pickup information.',
          permission: 'location',
        );
        
        if (shouldRequest) {
          final result = await requestLocationPermission();
          return result == PermissionStatus.granted;
        }
        return false;
        
      case PermissionStatus.permanentlyDenied:
        final shouldOpenSettings = await showSettingsDialog(context);
        return false; // User needs to manually enable in settings
        
      case PermissionStatus.restricted:
        return false;
        
      case PermissionStatus.limited:
        return true; // Limited access is still usable
        
      default:
        return false;
    }
  }

  /// Handle notification permission flow
  Future<bool> handleNotificationPermission(BuildContext context) async {
    final status = await Permission.notification.status;
    
    switch (status) {
      case PermissionStatus.granted:
        return true;
        
      case PermissionStatus.denied:
        final shouldRequest = await showPermissionRationale(
          context,
          title: 'Notification Permission',
          message: 'Enable notifications to receive updates about your rides, driver arrivals, and special offers.',
          permission: 'notification',
        );
        
        if (shouldRequest) {
          final result = await requestNotificationPermission();
          return result == PermissionStatus.granted;
        }
        return false;
        
      case PermissionStatus.permanentlyDenied:
        await showSettingsDialog(context);
        return false;
        
      default:
        return false;
    }
  }

  /// Request all essential permissions
  Future<Map<String, bool>> requestEssentialPermissions(BuildContext context) async {
    final results = <String, bool>{};
    
    // Location permission (essential)
    results['location'] = await handleLocationPermission(context);
    
    // Notification permission (recommended)
    results['notification'] = await handleNotificationPermission(context);
    
    return results;
  }
}
