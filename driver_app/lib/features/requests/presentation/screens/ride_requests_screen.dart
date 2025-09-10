import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../../../../core/services/native_websocket_service.dart';

class RideRequestsScreen extends StatefulWidget {
  const RideRequestsScreen({super.key});

  @override
  State<RideRequestsScreen> createState() => _RideRequestsScreenState();
}

class _RideRequestsScreenState extends State<RideRequestsScreen> {
  // REAL ride requests from WebSocket
  final List<Map<String, dynamic>> _rideRequests = [];
  StreamSubscription? _rideRequestsSubscription;

  @override
  void initState() {
    super.initState();
    _initializeWebSocketListeners();
  }

  @override
  void dispose() {
    _rideRequestsSubscription?.cancel();
    super.dispose();
  }

  void _initializeWebSocketListeners() {
    print('🚗 Driver Requests Screen: Listening for real ride requests...');
    
    // Listen for new ride requests from Go WebSocket
    _rideRequestsSubscription = DriverNativeWebSocketService.instance.rideRequests.listen((request) {
      print('🔔 Driver Requests Screen: New ride request received: $request');
      
      setState(() {
        // Add the new ride request to the list
        _rideRequests.insert(0, {
          'id': request['rideId'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
          'customerId': request['customerId'] ?? 'unknown',
          'customerName': request['customerName'] ?? 'Customer',
          'pickupAddress': request['pickup'] ?? 'Unknown pickup location',
          'destinationAddress': request['destination'] ?? 'Unknown destination',
          'distance': '${request['distance']?.toStringAsFixed(1) ?? '0.0'}km',
          'duration': '${request['duration']?.round() ?? 0}min',
          'customerOffer': request['customerFareOffer'] ?? 250,
          'passengerCount': request['passengerCount'] ?? 1,
          'requestTime': 'Just now',
          'status': 'pending',
          'pickupCoordinates': request['pickupCoordinates'],
          'destinationCoordinates': request['destinationCoordinates'],
        });
      });
      
      // Show notification
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔔 New ride request: ${request['pickup']} → ${request['destination']}'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 3),
        ),
      );
    });
    
    // Also listen for ride updates
    DriverNativeWebSocketService.instance.rideUpdates.listen((update) {
      print('🔄 Driver Requests Screen: Ride update: $update');
      // Handle ride updates (accepted, cancelled, etc.)
    });
  }

  void _acceptCustomerOffer(Map<String, dynamic> request) {
    print('✅ Driver accepting customer offer: ${request['id']}');
    
    // Send offer to customer via Go WebSocket
    DriverNativeWebSocketService.instance.sendRideOffer(
      rideId: request['id'],
      customerId: request['customerId'],
      fareOffer: (request['customerOffer'] as num).toDouble(),
      message: 'I accept your offer!',
    );
    
    // Update UI
    setState(() {
      final index = _rideRequests.indexWhere((r) => r['id'] == request['id']);
      if (index != -1) {
        _rideRequests[index]['status'] = 'offer_sent';
      }
    });
    
    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Offer sent to customer: PKR ${request['customerOffer']}'),
        backgroundColor: Colors.green,
      ),
    );
    
    setState(() {
      final index = _rideRequests.indexWhere((r) => r['id'] == request['id']);
      if (index != -1) {
        _rideRequests[index]['status'] = 'accepted';
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Accepted ride for PKR ${request['customerOffer']}'),
        backgroundColor: const Color(0xFF4CAF50),
      ),
    );
    
    // Navigate to trip tracking (TODO: Implement trip tracking screen)
    // context.push('/trip-tracking', extra: request);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Ride Requests'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4CAF50),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${_rideRequests.where((r) => r['status'] == 'pending').length} New',
                  style: const TextStyle(
                    color: Color(0xFF4CAF50),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _rideRequests.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _rideRequests.length,
              itemBuilder: (context, index) {
                final request = _rideRequests[index];
                return _buildRequestCard(request);
              },
            ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none,
              size: 50,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Ride Requests',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'New ride requests will appear here when you\'re online',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildRequestCard(Map<String, dynamic> request) {
    final status = request['status'] as String;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with customer info and offer
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF1B5E20),
                    child: Text(
                      request['customerName'].substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request['customerName'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${request['distance']} • ${request['duration']} • ${request['requestTime']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'PKR ${request['customerOffer']}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Route details
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4CAF50),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            request['pickupAddress'],
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            request['destinationAddress'],
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              
              // Action buttons
              if (status == 'pending')
                ElevatedButton(
                  onPressed: () => _acceptCustomerOffer(request),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: const Color(0xFF4CAF50),
                  ),
                  child: const Text(
                    'Accept Ride',
                    style: TextStyle(color: Colors.white),
                  ),
                )
              else if (status == 'accepted')
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Color(0xFF4CAF50),
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Ride accepted! Navigate to pickup',
                        style: TextStyle(
                          color: Color(0xFF4CAF50),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}