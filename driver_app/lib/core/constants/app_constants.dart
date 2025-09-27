class AppConstants {
  // App Info
  static const String appName = 'Drivrr Driver';
  static const String appVersion = '1.0.0';
  
  // API Configuration
  static const String baseUrl = 'http://localhost:3000/api'; // Node.js backend for OTP/Auth
  static const String socketUrl = 'ws://localhost:8081/ws'; // Go backend for WebSocket
  static const Duration requestTimeout = Duration(seconds: 30);
  
  // Driver Status
  static const List<String> driverStatuses = [
    'offline',
    'online',
    'busy',
    'on_trip',
  ];
  
  // Vehicle Types
  static const List<String> vehicleTypes = [
    'economy',
    'comfort', 
    'premium',
    'xl',
  ];
  
  // Ride Status
  static const List<String> rideStatuses = [
    'pending',
    'haggling',
    'accepted',
    'driver_arrived',
    'in_progress',
    'completed',
    'cancelled',
  ];
  
  // App Colors (Driver Theme)
  static const int primaryColorValue = 0xFF1B5E20; // Dark Green for drivers
  static const int secondaryColorValue = 0xFF4CAF50; // Light Green
  static const int accentColorValue = 0xFFFF9800; // Orange for earnings
  
  // Map Configuration
  static const double defaultZoom = 13.0;
  static const double maxZoom = 18.0;
  static const double minZoom = 3.0;
  
  // Location Settings
  static const double locationUpdateIntervalSeconds = 10.0;
  static const double nearbyRideRadiusKm = 10.0;
  
  // Notification Settings
  static const String rideRequestChannel = 'ride_requests';
  static const String tripUpdatesChannel = 'trip_updates';
  
  // Driver Verification Documents
  static const List<String> requiredDocuments = [
    'driving_license',
    'vehicle_registration',
    'insurance_certificate',
    'driver_photo',
    'vehicle_photo',
  ];
  
  // Earnings
  static const double platformCommissionRate = 0.15; // 15% platform fee
  static const double minimumWithdrawal = 500.0; // PKR
}
