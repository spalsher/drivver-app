class AppConstants {
  static const String appName = 'Drivrr';
  static const String appVersion = '1.0.0';
  
  // API Configuration
  static const String baseUrl = 'http://192.168.20.67:3000/api';
  static const String socketUrl = 'http://192.168.20.67:3000';
  
  // MapTiler Configuration  
  static const String mapTilerApiKey = 'zKmHEI76JocEKpcky18z'; // Default API Key (working)
  static const String mapStyle = 'https://api.maptiler.com/maps/streets-v2/style.json';
  
  // App Settings
  static const int maxHagglingRounds = 3;
  static const int hagglingTimeoutMinutes = 5;
  static const double driverSearchRadiusKm = 10.0;
  static const int maxRideRequestTimeMinutes = 15;
  
  // Fare Settings
  static const double minimumFare = 5.0;
  static const double maximumFare = 500.0;
  static const double baseFarePerKm = 2.5;
  
  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 300);
  static const Duration mediumAnimation = Duration(milliseconds: 600);
  static const Duration longAnimation = Duration(milliseconds: 1000);
  
  // Asset Paths
  static const String imagesPath = 'assets/images/';
  static const String iconsPath = 'assets/icons/';
  static const String animationsPath = 'assets/animations/';
  
  // SharedPreferences Keys
  static const String keyAuthToken = 'auth_token';
  static const String keyUserId = 'user_id';
  static const String keyUserEmail = 'user_email';
  static const String keyIsFirstLaunch = 'is_first_launch';
  static const String keyThemeMode = 'theme_mode';
  static const String keyLanguage = 'language';
  static const String keyNotificationsEnabled = 'notifications_enabled';
  static const String keyLocationPermissionAsked = 'location_permission_asked';
  
  // Error Messages
  static const String genericErrorMessage = 'Something went wrong. Please try again.';
  static const String networkErrorMessage = 'Please check your internet connection.';
  static const String locationErrorMessage = 'Location permission is required for this app.';
  static const String authErrorMessage = 'Please login again to continue.';
  
  // Validation
  static const int minPasswordLength = 6;
  static const int maxNameLength = 50;
  static const int minNameLength = 2;
  
  // Map Configuration
  static const double defaultZoom = 15.0;
  static const double minZoom = 5.0;
  static const double maxZoom = 20.0;
  
  // Location Update Settings
  static const Duration locationUpdateInterval = Duration(seconds: 5);
  static const double locationAccuracyMeters = 10.0;
  
  // UI Constants
  static const double borderRadius = 12.0;
  static const double cardBorderRadius = 16.0;
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  
  // Bottom Sheet Heights
  static const double bookingBottomSheetHeight = 0.7;
  static const double hagglingBottomSheetHeight = 0.8;
  static const double paymentBottomSheetHeight = 0.6;
  
  // Vehicle Types
  static const List<String> vehicleTypes = [
    'Economy',
    'Standard',
    'Premium',
    'SUV',
  ];
  
  // Ride Status
  static const String rideStatusPending = 'pending';
  static const String rideStatusHaggling = 'haggling';
  static const String rideStatusAccepted = 'accepted';
  static const String rideStatusDriverAssigned = 'driver_assigned';
  static const String rideStatusInProgress = 'in_progress';
  static const String rideStatusCompleted = 'completed';
  static const String rideStatusCancelled = 'cancelled';
}

