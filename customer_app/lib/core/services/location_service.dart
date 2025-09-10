import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  bool _isInitialized = false;
  bool _hasLocationPermission = false;
  bool _permissionRequested = false;

  // Check if location services are available
  Future<bool> isLocationServiceEnabled() async {
    try {
      // On mobile, check if location services are enabled
      final serviceStatus = await Permission.location.serviceStatus;
      return serviceStatus.isEnabled;
    } catch (e) {
      debugPrint('Error checking location service: $e');
      return false;
    }
  }

  // Get current permission status
  Future<PermissionStatus> getLocationPermissionStatus() async {
    return await Permission.location.status;
  }

  // Request location permission with proper user experience
  Future<bool> requestLocationPermission({bool showRationale = true}) async {
    if (_permissionRequested && _hasLocationPermission) {
      return _hasLocationPermission;
    }

    try {
      debugPrint('🗺️ LocationService: Requesting location permission...');
      
      final permission = Permission.location;
      var status = await permission.status;
      
      debugPrint('🗺️ LocationService: Current status: $status');

      // If already granted, return true
      if (status.isGranted) {
        _hasLocationPermission = true;
        _permissionRequested = true;
        debugPrint('✅ LocationService: Permission already granted');
        return true;
      }

      // If denied, request permission
      if (status.isDenied) {
        debugPrint('🔄 LocationService: Requesting permission...');
        status = await permission.request();
        debugPrint('🔄 LocationService: Permission result: $status');
      }

      // Handle the result
      _permissionRequested = true;
      _hasLocationPermission = status.isGranted;

      if (status.isGranted) {
        debugPrint('✅ LocationService: Permission granted successfully');
        return true;
      } else if (status.isPermanentlyDenied) {
        debugPrint('❌ LocationService: Permission permanently denied');
        return false;
      } else {
        debugPrint('❌ LocationService: Permission denied');
        return false;
      }
    } catch (e) {
      debugPrint('❌ LocationService: Error requesting permission: $e');
      return false;
    }
  }

  // Initialize location services
  Future<LocationInitResult> initialize() async {
    if (_isInitialized) {
      return LocationInitResult(
        success: _hasLocationPermission,
        hasPermission: _hasLocationPermission,
        serviceEnabled: await isLocationServiceEnabled(),
        message: 'Already initialized',
      );
    }

    debugPrint('🚀 LocationService: Initializing...');

    try {
      // Check if location service is enabled
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('❌ LocationService: Location service is disabled');
        return LocationInitResult(
          success: false,
          hasPermission: false,
          serviceEnabled: false,
          message: 'Location service is disabled. Please enable it in device settings.',
        );
      }

      // Request permission
      final hasPermission = await requestLocationPermission();
      
      _isInitialized = true;
      
      final result = LocationInitResult(
        success: hasPermission,
        hasPermission: hasPermission,
        serviceEnabled: serviceEnabled,
        message: hasPermission 
          ? 'Location services initialized successfully'
          : 'Location permission denied',
      );

      debugPrint('🏁 LocationService: Initialization complete - Success: ${result.success}');
      return result;
    } catch (e) {
      debugPrint('❌ LocationService: Initialization failed: $e');
      return LocationInitResult(
        success: false,
        hasPermission: false,
        serviceEnabled: false,
        message: 'Failed to initialize location services: $e',
      );
    }
  }

  // Check if we can get location
  Future<bool> canGetLocation() async {
    if (!_isInitialized) {
      final result = await initialize();
      return result.success;
    }
    
    return _hasLocationPermission && await isLocationServiceEnabled();
  }

  // Open app settings for permission
  Future<void> openAppSettings() async {
    try {
      await Permission.location.request();
      // If still denied, open settings
      final status = await Permission.location.status;
      if (status.isPermanentlyDenied) {
        await openAppSettings();
      }
    } catch (e) {
      debugPrint('Error opening app settings: $e');
    }
  }

  // Reset the service state (useful for testing)
  void reset() {
    _isInitialized = false;
    _hasLocationPermission = false;
    _permissionRequested = false;
    debugPrint('🔄 LocationService: Reset complete');
  }

  // Getters
  bool get isInitialized => _isInitialized;
  bool get hasLocationPermission => _hasLocationPermission;
  bool get permissionRequested => _permissionRequested;
}

class LocationInitResult {
  final bool success;
  final bool hasPermission;
  final bool serviceEnabled;
  final String message;

  LocationInitResult({
    required this.success,
    required this.hasPermission,
    required this.serviceEnabled,
    required this.message,
  });

  @override
  String toString() {
    return 'LocationInitResult(success: $success, hasPermission: $hasPermission, serviceEnabled: $serviceEnabled, message: $message)';
  }
}