import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math' as math;

class DriverMapWidget extends StatefulWidget {
  final bool isOnline;
  final Function(Map<String, dynamic>)? onRideRequestTapped;
  
  const DriverMapWidget({
    super.key,
    required this.isOnline,
    this.onRideRequestTapped,
  });

  @override
  State<DriverMapWidget> createState() => _DriverMapWidgetState();
}

class _DriverMapWidgetState extends State<DriverMapWidget> {
  final MapController _mapController = MapController();
  LatLng _driverLocation = const LatLng(24.8607, 67.0011); // Default to Karachi
  bool _isLocationLoaded = false;
  Timer? _locationUpdateTimer;
  
  // Sample nearby ride requests (TODO: Get from backend)
  final List<Map<String, dynamic>> _nearbyRideRequests = [
    {
      'id': '1',
      'pickup': {'lat': 24.8700, 'lng': 67.0100},
      'destination': {'lat': 24.8500, 'lng': 67.0200},
      'pickupAddress': 'Gulshan-e-Iqbal, Karachi',
      'destinationAddress': 'Clifton, Karachi',
      'customerOffer': 250,
      'distance': 3.2,
      'estimatedDuration': 8,
      'customerName': 'Ahmed Khan',
      'passengerCount': 1,
    },
    {
      'id': '2', 
      'pickup': {'lat': 24.8800, 'lng': 67.0050},
      'destination': {'lat': 24.8300, 'lng': 67.0400},
      'pickupAddress': 'Nazimabad, Karachi',
      'destinationAddress': 'DHA Phase 5, Karachi',
      'customerOffer': 320,
      'distance': 5.1,
      'estimatedDuration': 12,
      'customerName': 'Fatima Ali',
      'passengerCount': 2,
    },
    {
      'id': '3',
      'pickup': {'lat': 24.8400, 'lng': 67.0300},
      'destination': {'lat': 24.9000, 'lng': 67.0800},
      'pickupAddress': 'Saddar, Karachi',
      'destinationAddress': 'Malir, Karachi',
      'customerOffer': 180,
      'distance': 2.8,
      'estimatedDuration': 7,
      'customerName': 'Hassan Sheikh',
      'passengerCount': 1,
    },
  ];
  
  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _startLocationUpdates();
  }
  
  @override
  void didUpdateWidget(DriverMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isOnline != oldWidget.isOnline) {
      if (widget.isOnline) {
        _startLocationUpdates();
      } else {
        _stopLocationUpdates();
      }
    }
  }
  
  Future<void> _getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }
      
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        return;
      }
      
      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _driverLocation = LatLng(position.latitude, position.longitude);
          _isLocationLoaded = true;
        });
        
        // Move map to driver location
        _mapController.move(_driverLocation, 15.0);
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }
  
  void _startLocationUpdates() {
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (widget.isOnline) {
        _getCurrentLocation();
        // TODO: Send location update to backend via WebSocket
      }
    });
  }
  
  void _stopLocationUpdates() {
    _locationUpdateTimer?.cancel();
  }
  
  void _moveToDriverLocation() {
    if (_isLocationLoaded) {
      _mapController.move(_driverLocation, 15.0);
    } else {
      _getCurrentLocation();
    }
  }
  
  void _onRideRequestTapped(Map<String, dynamic> request) {
    widget.onRideRequestTapped?.call(request);
  }
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _driverLocation,
            initialZoom: 13.0,
            minZoom: 3.0,
            maxZoom: 18.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.drivrr.driver',
              maxZoom: 19,
            ),
            
            // Driver location marker
            if (_isLocationLoaded)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _driverLocation,
                    width: 50,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        color: widget.isOnline ? const Color(0xFF4CAF50) : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.isOnline ? Icons.drive_eta : Icons.location_off,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            
            // Nearby ride request markers (only when online)
            if (widget.isOnline)
              MarkerLayer(
                markers: _nearbyRideRequests.map((request) {
                  final pickup = LatLng(request['pickup']['lat'], request['pickup']['lng']);
                  return Marker(
                    point: pickup,
                    width: 60,
                    height: 60,
                    child: GestureDetector(
                      onTap: () => _onRideRequestTapped(request),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 16,
                            ),
                            Text(
                              'PKR ${request['customerOffer']}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
        
        // Driver location button
        Positioned(
          bottom: 200,
          right: 20,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _moveToDriverLocation,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.my_location,
                    color: Color(0xFF1B5E20),
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ),
        
        // Online status indicator
        if (widget.isOnline)
          Positioned(
            top: 50,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'ONLINE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        
        // Attribution
        const Positioned(
          bottom: 5,
          left: 5,
          child: Text(
            '© OpenStreetMap',
            style: TextStyle(
              fontSize: 10,
              color: Colors.black54,
            ),
          ),
        ),
      ],
    );
  }
  
  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    super.dispose();
  }
}
