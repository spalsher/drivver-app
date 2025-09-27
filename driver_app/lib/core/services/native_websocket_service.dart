import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';

class DriverNativeWebSocketService {
  static final DriverNativeWebSocketService instance = DriverNativeWebSocketService._internal();
  factory DriverNativeWebSocketService() => instance;
  DriverNativeWebSocketService._internal();

  WebSocket? _socket;
  bool _isConnected = false;
  String? _driverId;

  // Stream controllers
  final _connectionController = StreamController<String>.broadcast();
  final _rideRequestsController = StreamController<Map<String, dynamic>>.broadcast();
  final _rideUpdatesController = StreamController<Map<String, dynamic>>.broadcast();

  // Getters
  Stream<String> get connectionStatus => _connectionController.stream;
  Stream<Map<String, dynamic>> get rideRequests => _rideRequestsController.stream;
  Stream<Map<String, dynamic>> get rideUpdates => _rideUpdatesController.stream;
  bool get isConnected => _isConnected;

  /// Connect to Go WebSocket backend
  Future<void> connect(String driverId) async {
    if (_isConnected) return;

    _driverId = driverId;

    try {
      final uri = Uri.parse('${AppConstants.socketUrl}?userId=$driverId&userType=driver');
      
      debugPrint('🚗 Driver connecting to Go WebSocket: $uri');
      
      _socket = await WebSocket.connect(uri.toString());
      _isConnected = true;
      
      debugPrint('✅ Driver connected to Go WebSocket backend');
      _connectionController.add('connected');
      
      // Listen for messages
      _socket!.listen(
        (data) => _handleMessage(data),
        onError: (error) {
          debugPrint('❌ Driver WebSocket error: $error');
          _isConnected = false;
          _connectionController.add('error');
        },
        onDone: () {
          debugPrint('🔌 Driver WebSocket connection closed');
          _isConnected = false;
          _connectionController.add('disconnected');
        },
      );
      
      // Set driver as online
      setDriverStatus(true);
      
    } catch (e) {
      debugPrint('❌ Failed to connect driver to WebSocket: $e');
      _isConnected = false;
      _connectionController.add('error');
    }
  }

  void _handleMessage(dynamic data) {
    try {
      final message = jsonDecode(data);
      final type = message['type'];
      final messageData = message['data'] ?? {};
      
      debugPrint('📨 Driver received WebSocket message: $type');
      
      switch (type) {
        case 'new_ride_request':
          debugPrint('🚗 NEW RIDE REQUEST for driver');
          _rideRequestsController.add(messageData);
          break;
          
        case 'offer_accepted':
          debugPrint('✅ Driver offer accepted - starting ride');
          _rideUpdatesController.add(messageData);
          break;
          
        case 'offer_rejected':
          debugPrint('❌ Driver offer rejected: ${messageData['reason']}');
          _rideUpdatesController.add(messageData);
          break;
          
        case 'ride_cancelled':
          debugPrint('❌ Ride cancelled');
          _rideUpdatesController.add(messageData);
          break;
          
        case 'pong':
          debugPrint('🏓 Driver pong received');
          break;
          
        default:
          debugPrint('⚠️ Unknown driver message type: $type');
      }
    } catch (e) {
      debugPrint('❌ Failed to parse driver WebSocket message: $e');
    }
  }

  void _sendMessage(Map<String, dynamic> message) {
    if (_isConnected && _socket != null) {
      try {
        final jsonString = jsonEncode(message);
        _socket!.add(jsonString);
        debugPrint('📤 Driver sent WebSocket message: ${message['type']}');
      } catch (e) {
        debugPrint('❌ Failed to send driver WebSocket message: $e');
      }
    } else {
      debugPrint('❌ Cannot send driver message - WebSocket not connected');
    }
  }

  /// Send driver offer
  void sendRideOffer({
    required String rideId,
    required String customerId,
    required double fareOffer,
    String? message,
  }) {
    debugPrint('💰 Driver sending offer: PKR $fareOffer for ride $rideId');
    
    final offerMessage = {
      'type': 'driver_offer',
      'rideId': rideId,
      'customerId': customerId,
      'offer': fareOffer,
      'message': message ?? 'I accept your fare!',
      'driverId': _driverId,
    };
    
    _sendMessage(offerMessage);
  }

  /// Set driver online/offline status
  void setDriverStatus(bool isOnline) {
    final statusMessage = {
      'type': 'driver_status',
      'isOnline': isOnline,
      'driverId': _driverId,
    };
    
    _sendMessage(statusMessage);
    debugPrint('🚗 Driver status updated: ${isOnline ? 'ONLINE' : 'OFFLINE'}');
  }

  /// Update driver location during ride
  void updateDriverLocation({
    required String rideId,
    required double latitude,
    required double longitude,
  }) {
    final locationMessage = {
      'type': 'driver_location_update',
      'rideId': rideId,
      'latitude': latitude,
      'longitude': longitude,
      'driverId': _driverId,
    };
    
    _sendMessage(locationMessage);
    debugPrint('📍 Driver location updated: $latitude, $longitude');
  }

  /// Complete ride
  void completeRide(String rideId) {
    final completeMessage = {
      'type': 'complete_ride',
      'rideId': rideId,
      'driverId': _driverId,
    };
    
    _sendMessage(completeMessage);
    debugPrint('🏁 Ride $rideId marked as completed');
  }

  /// Disconnect WebSocket
  void disconnect() {
    if (_socket != null) {
      _socket!.close();
      _socket = null;
    }
    _isConnected = false;
    _connectionController.add('disconnected');
    debugPrint('🔌 Driver WebSocket disconnected');
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _connectionController.close();
    _rideRequestsController.close();
    _rideUpdatesController.close();
  }
}
