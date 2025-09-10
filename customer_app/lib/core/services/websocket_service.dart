import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';

class WebSocketService {
  static WebSocketService? _instance;
  static WebSocketService get instance => _instance ??= WebSocketService._internal();
  
  WebSocketService._internal();
  
  IO.Socket? _socket;
  bool _isConnected = false;
  String? _userId;
  
  // Stream controllers for different events
  final StreamController<Map<String, dynamic>> _driverOfferController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _rideUpdateController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _connectionController = 
      StreamController<String>.broadcast();
  
  // Trip tracking stream controllers
  final StreamController<Map<String, dynamic>> _driverLocationController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _tripStatusController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  // Getters for streams
  Stream<Map<String, dynamic>> get driverOffers => _driverOfferController.stream;
  Stream<Map<String, dynamic>> get rideUpdates => _rideUpdateController.stream;
  Stream<String> get connectionStatus => _connectionController.stream;
  
  // Trip tracking streams
  Stream<Map<String, dynamic>> get driverLocationUpdates => _driverLocationController.stream;
  Stream<Map<String, dynamic>> get tripStatusUpdates => _tripStatusController.stream;
  
  bool get isConnected => _isConnected;
  
  /// Initialize WebSocket connection
  Future<void> connect(String userId) async {
    if (_isConnected) return;
    
    _userId = userId;
    
    try {
      final socketUrl = AppConstants.baseUrl.replaceAll('/api', '');
      debugPrint('🔌 WebSocket connecting to: $socketUrl');
      debugPrint('🔌 WebSocket user ID: $userId');
      
      _socket = IO.io(
        socketUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .setExtraHeaders({'user-id': userId})
            .setTimeout(10000) // 10 second timeout
            .build(),
      );
      
      _setupEventListeners();
      _socket!.connect();
      
      debugPrint('🔌 WebSocket connection initiated...');
      
      // Wait for connection to establish
      int attempts = 0;
      while (!_isConnected && attempts < 50) { // 5 seconds max wait
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
      
      debugPrint('🔌 WebSocket final status: connected=$_isConnected after ${attempts * 100}ms');
      
    } catch (e) {
      debugPrint('❌ WebSocket connection error: $e');
      _connectionController.add('error');
    }
  }
  
  void _setupEventListeners() {
    _socket!.onConnect((_) {
      _isConnected = true;
      debugPrint('✅ WebSocket connected successfully');
      _connectionController.add('connected');
      
      // Join user room for personalized updates
      debugPrint('🏠 Joining user room for: $_userId');
      _socket!.emit('join_user_room', {'userId': _userId});
      debugPrint('🏠 User room join request sent');
    });
    
    _socket!.onDisconnect((_) {
      _isConnected = false;
      debugPrint('🔌 WebSocket disconnected');
      _connectionController.add('disconnected');
    });
    
    _socket!.onConnectError((data) {
      debugPrint('❌ WebSocket connection error: $data');
      _connectionController.add('error');
    });
    
    // Listen for driver offers
    _socket!.on('driver_offer', (data) {
      debugPrint('💰 Received driver offer: $data');
      _driverOfferController.add(Map<String, dynamic>.from(data));
    });
    
    // Listen for counter-offer responses
    _socket!.on('counter_offer_response', (data) {
      debugPrint('🔄 Counter-offer response: $data');
      _driverOfferController.add(Map<String, dynamic>.from(data));
    });
    
    // Listen for ride updates
    _socket!.on('ride_update', (data) {
      debugPrint('🚗 Ride update: $data');
      _rideUpdateController.add(Map<String, dynamic>.from(data));
    });
    
    // Trip tracking event listeners
    _socket!.on('driver_location_update', (data) {
      debugPrint('📍 Driver location update: $data');
      _driverLocationController.add(Map<String, dynamic>.from(data));
    });
    
    _socket!.on('trip_status_update', (data) {
      debugPrint('🚦 Trip status update: $data');
      _tripStatusController.add(Map<String, dynamic>.from(data));
    });
    
    _socket!.on('trip_progress_update', (data) {
      debugPrint('📊 Trip progress update: $data');
      _tripStatusController.add(Map<String, dynamic>.from(data));
    });
    
    // Listen for driver location updates
    _socket!.on('driver_location', (data) {
      debugPrint('📍 Driver location update: $data');
      _rideUpdateController.add({
        'type': 'driver_location',
        'data': data,
      });
    });
  }
  
  /// Create a new ride request
  void createRideRequest(Map<String, dynamic> rideData) {
    debugPrint('🚗 Attempting to create ride request...');
    debugPrint('🔌 WebSocket connected: $_isConnected');
    debugPrint('📍 Ride data: ${rideData['pickup']} → ${rideData['destination']}');
    
    if (_isConnected) {
      debugPrint('✅ Sending ride request to Go backend...');
      
      // Format message for Go backend
      final message = {
        'type': 'create_ride_request',
        'pickup': rideData['pickup'],
        'destination': rideData['destination'],
        'pickupLat': rideData['pickupLat'],
        'pickupLng': rideData['pickupLng'],
        'destLat': rideData['destLat'],
        'destLng': rideData['destLng'],
        'customerFareOffer': rideData['customerFareOffer'],
        'vehicleType': rideData['vehicleType'],
        'distance': rideData['distance'],
        'duration': rideData['duration'],
        'customerId': _userId,
      };
      
      // Send as JSON string to Go WebSocket
      _socket!.emit('message', message);
      debugPrint('📡 Ride request sent to Go backend: $message');
    } else {
      debugPrint('❌ Cannot create ride request - WebSocket not connected!');
      debugPrint('🔄 Attempting to reconnect...');
      // Try to reconnect
      if (_userId != null) {
        connect(_userId!);
      }
    }
  }
  
  /// Send counter-offer to driver
  void sendCounterOffer({
    required String rideId,
    required String driverId,
    required int newPrice,
  }) {
    if (_isConnected) {
      debugPrint('💰 Sending counter-offer: PKR $newPrice to driver $driverId');
      _socket!.emit('counter_offer', {
        'rideId': rideId,
        'driverId': driverId,
        'newPrice': newPrice,
        'userId': _userId,
      });
    }
  }
  
  /// Accept driver offer
  void acceptOffer({
    required String rideId,
    required String driverId,
    required int finalPrice,
  }) {
    if (_isConnected) {
      debugPrint('✅ Accepting offer: PKR $finalPrice from driver $driverId');
      _socket!.emit('accept_offer', {
        'rideId': rideId,
        'driverId': driverId,
        'finalPrice': finalPrice,
        'userId': _userId,
      });
    }
  }
  
  /// Cancel ride request
  void cancelRideRequest(String rideId) {
    if (_isConnected) {
      debugPrint('❌ Cancelling ride request: $rideId');
      _socket!.emit('cancel_ride', {
        'rideId': rideId,
        'userId': _userId,
      });
    }
  }
  
  /// Update user location
  void updateUserLocation(double lat, double lng) {
    if (_isConnected) {
      _socket!.emit('update_location', {
        'userId': _userId,
        'latitude': lat,
        'longitude': lng,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }
  
  // ==================== TRIP TRACKING METHODS ====================
  
  /// Request driver location for active trip
  void requestDriverLocation(String rideId) {
    if (_isConnected) {
      debugPrint('📍 Requesting driver location for ride: $rideId');
      _socket!.emit('request_driver_location', {
        'rideId': rideId,
        'userId': _userId,
      });
    }
  }
  
  /// Start trip tracking
  void startTripTracking(String rideId) {
    if (_isConnected) {
      debugPrint('🚗 Starting trip tracking for ride: $rideId');
      _socket!.emit('start_trip_tracking', {
        'rideId': rideId,
        'userId': _userId,
      });
    }
  }
  
  /// Update trip status
  void updateTripStatus(String rideId, String status) {
    if (_isConnected) {
      debugPrint('🚦 Updating trip status: $status for ride: $rideId');
      _socket!.emit('update_trip_status', {
        'rideId': rideId,
        'status': status,
        'userId': _userId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }
  
  /// Cancel active trip
  void cancelTrip(String rideId) {
    if (_isConnected) {
      debugPrint('❌ Canceling trip: $rideId');
      _socket!.emit('cancel_trip', {
        'rideId': rideId,
        'userId': _userId,
        'reason': 'User canceled',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }
  
  /// Request trip details
  void requestTripDetails(String rideId) {
    if (_isConnected) {
      debugPrint('📋 Requesting trip details for ride: $rideId');
      _socket!.emit('request_trip_details', {
        'rideId': rideId,
        'userId': _userId,
      });
    }
  }
  
  /// Disconnect WebSocket
  Future<void> disconnect() async {
    if (_socket != null) {
      debugPrint('🔌 Disconnecting WebSocket...');
      _socket!.disconnect();
      _socket = null;
      _isConnected = false;
    }
  }
  
  /// Dispose resources
  void dispose() {
    disconnect();
    _driverOfferController.close();
    _rideUpdateController.close();
    _connectionController.close();
    _driverLocationController.close();
    _tripStatusController.close();
  }
}
