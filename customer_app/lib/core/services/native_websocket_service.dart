import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';

class NativeWebSocketService {
  static final NativeWebSocketService instance = NativeWebSocketService._internal();
  factory NativeWebSocketService() => instance;
  NativeWebSocketService._internal();

  WebSocket? _socket;
  bool _isConnected = false;
  String? _userId;
  String? _userType;

  // Stream controllers
  final _connectionController = StreamController<String>.broadcast();
  final _driverOffersController = StreamController<Map<String, dynamic>>.broadcast();
  final _rideUpdateController = StreamController<Map<String, dynamic>>.broadcast();

  // Getters
  Stream<String> get connectionStatus => _connectionController.stream;
  Stream<Map<String, dynamic>> get driverOffers => _driverOffersController.stream;
  Stream<Map<String, dynamic>> get rideUpdates => _rideUpdateController.stream;
  bool get isConnected => _isConnected;

  /// Connect to Go WebSocket backend
  Future<void> connect(String userId, {String userType = 'customer'}) async {
    if (_isConnected) return;

    _userId = userId;
    _userType = userType;

    try {
      final wsUrl = AppConstants.baseUrl.replaceAll('/api', '').replaceAll('http', 'ws');
      final uri = Uri.parse('$wsUrl/ws?userId=$userId&userType=$userType');
      
      debugPrint('🔌 Connecting to Go WebSocket: $uri');
      
      _socket = await WebSocket.connect(uri.toString());
      _isConnected = true;
      
      debugPrint('✅ Connected to Go WebSocket backend');
      _connectionController.add('connected');
      
      // Listen for messages
      _socket!.listen(
        (data) => _handleMessage(data),
        onError: (error) {
          debugPrint('❌ WebSocket error: $error');
          _isConnected = false;
          _connectionController.add('error');
        },
        onDone: () {
          debugPrint('🔌 WebSocket connection closed');
          _isConnected = false;
          _connectionController.add('disconnected');
        },
      );
      
      // Send ping to confirm connection
      _sendMessage({'type': 'ping', 'userId': userId});
      
    } catch (e) {
      debugPrint('❌ Failed to connect to WebSocket: $e');
      _isConnected = false;
      _connectionController.add('error');
    }
  }

  void _handleMessage(dynamic data) {
    try {
      final message = jsonDecode(data);
      final type = message['type'];
      final messageData = message['data'] ?? {};
      
      debugPrint('📨 Received WebSocket message: $type');
      
      switch (type) {
        case 'new_ride_request':
          debugPrint('🚗 New ride request received');
          _rideUpdateController.add(messageData);
          break;
          
        case 'driver_offer':
          debugPrint('💰 Driver offer received: ${messageData['offer']}');
          _driverOffersController.add(messageData);
          break;
          
        case 'offer_accepted':
          debugPrint('✅ Offer accepted');
          _rideUpdateController.add(messageData);
          break;
          
        case 'driver_assigned':
          debugPrint('🚗 Driver assigned with ETA: ${messageData['driverETA']} minutes');
          _rideUpdateController.add(messageData);
          break;
          
        case 'driver_location_update':
          debugPrint('📍 Driver location update - ETA: ${messageData['eta']} minutes');
          _rideUpdateController.add(messageData);
          break;
          
        case 'ride_completed':
          debugPrint('🏁 Ride completed');
          _rideUpdateController.add(messageData);
          break;
          
        case 'pong':
          debugPrint('🏓 Pong received');
          break;
          
        default:
          debugPrint('⚠️ Unknown message type: $type');
      }
    } catch (e) {
      debugPrint('❌ Failed to parse WebSocket message: $e');
    }
  }

  void _sendMessage(Map<String, dynamic> message) {
    if (_isConnected && _socket != null) {
      try {
        final jsonString = jsonEncode(message);
        _socket!.add(jsonString);
        debugPrint('📤 Sent WebSocket message: ${message['type']}');
      } catch (e) {
        debugPrint('❌ Failed to send WebSocket message: $e');
      }
    } else {
      debugPrint('❌ Cannot send message - WebSocket not connected');
    }
  }

  /// Create a ride request
  void createRideRequest(Map<String, dynamic> rideData) {
    debugPrint('🚗 Creating ride request via native WebSocket...');
    debugPrint('📍 Route: ${rideData['pickup']} → ${rideData['destination']}');
    
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
    
    _sendMessage(message);
    debugPrint('🚀 Ride request sent to Go backend!');
  }

  /// Send driver offer
  void sendDriverOffer({
    required String rideId,
    required String customerId,
    required double offer,
    String? message,
  }) {
    final offerMessage = {
      'type': 'driver_offer',
      'rideId': rideId,
      'customerId': customerId,
      'offer': offer,
      'message': message ?? 'I accept your fare!',
      'driverId': _userId,
    };
    
    _sendMessage(offerMessage);
    debugPrint('💰 Driver offer sent: PKR $offer');
  }

  /// Accept driver offer
  void acceptOffer({
    required String rideId,
    required String driverId,
    required double finalPrice,
    required double pickupLat,
    required double pickupLng,
    required double destLat,
    required double destLng,
  }) {
    final acceptMessage = {
      'type': 'accept_offer',
      'rideId': rideId,
      'driverId': driverId,
      'finalPrice': finalPrice,
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'destLat': destLat,
      'destLng': destLng,
      'customerId': _userId,
    };
    
    _sendMessage(acceptMessage);
    debugPrint('✅ Offer acceptance sent with location data');
  }

  /// Update driver status
  void setDriverStatus(bool isOnline) {
    final statusMessage = {
      'type': 'driver_status',
      'isOnline': isOnline,
      'driverId': _userId,
    };
    
    _sendMessage(statusMessage);
    debugPrint('🚗 Driver status updated: ${isOnline ? 'ONLINE' : 'OFFLINE'}');
  }

  /// Disconnect WebSocket
  void disconnect() {
    if (_socket != null) {
      _socket!.close();
      _socket = null;
    }
    _isConnected = false;
    _connectionController.add('disconnected');
    debugPrint('🔌 WebSocket disconnected');
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _connectionController.close();
    _driverOffersController.close();
    _rideUpdateController.close();
  }
}
