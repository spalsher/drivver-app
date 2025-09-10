import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/services/routing_service.dart';
import '../../../home/presentation/widgets/flutter_map_widget.dart';

class RoutePreviewScreen extends StatefulWidget {
  const RoutePreviewScreen({super.key});

  @override
  State<RoutePreviewScreen> createState() => _RoutePreviewScreenState();
}

class _RoutePreviewScreenState extends State<RoutePreviewScreen> {
  Map<String, dynamic>? _locationData;
  RouteResult? _routeResult;
  bool _isLoading = true;
  
  // Sample coordinates for pickup and destination
  LatLng? _pickupLocation;
  LatLng? _destinationLocation;
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get location data passed from previous screen
    final extra = GoRouterState.of(context).extra;
    if (extra != null && extra is Map<String, dynamic>) {
      _locationData = extra;
      _setupLocations();
    }
  }
  
  void _setupLocations() {
    if (_locationData != null) {
      _pickupLocation = LatLng(
        _locationData!['pickupLat'] ?? 24.8607,
        _locationData!['pickupLng'] ?? 67.0011,
      );
      _destinationLocation = LatLng(
        _locationData!['destLat'] ?? 24.8138,
        _locationData!['destLng'] ?? 67.0300,
      );
      
      print('📍 RoutePreview - Pickup: ${_pickupLocation?.latitude}, ${_pickupLocation?.longitude}');
      print('📍 RoutePreview - Destination: ${_destinationLocation?.latitude}, ${_destinationLocation?.longitude}');
      
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _onRouteCalculated(RouteResult route) {
    setState(() {
      _routeResult = route;
    });
  }
  
  void _proceedToBooking() {
    final routeData = {
      ..._locationData ?? {},
      'hasRoute': _routeResult != null,
    };
    
    if (_routeResult != null) {
      routeData.addAll({
        'actualDistance': _routeResult!.distanceInKm,
        'actualDuration': _routeResult!.durationInMinutes,
        'formattedDistance': _routeResult!.formattedDistance,
        'formattedDuration': _routeResult!.formattedDuration,
        'routePoints': _routeResult!.points.length,
      });
    } else {
      // Fallback with estimated values
      routeData.addAll({
        'actualDistance': 5.5, // Default distance in km
        'actualDuration': 15, // Default duration in minutes
        'formattedDistance': '5.5km',
        'formattedDuration': '15min',
        'routePoints': 0,
      });
    }
    
    context.push('/ride-booking', extra: routeData);
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Route Preview'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
                // Map with route
                FlutterMapWidget(
                  pickupLocation: _pickupLocation,
                  destinationLocation: _destinationLocation,
                  onRouteCalculated: _onRouteCalculated,
                ),
          
          // Route details panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Route summary
                      if (_routeResult != null) ...[
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.route,
                                color: Colors.blue[700],
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_routeResult!.formattedDistance} • ${_routeResult!.formattedDuration}',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Fastest route via main roads',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.route,
                                color: Colors.orange[700],
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Calculating route...',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Please wait while we find the best route',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                      
                      const SizedBox(height: 20),
                      
                      // Location details
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _locationData?['pickup'] ?? 'Pickup Location',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              height: 20,
                              child: CustomPaint(
                                painter: DottedLinePainter(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _locationData?['destination'] ?? 'Destination',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Continue button
                      ElevatedButton(
                        onPressed: _proceedToBooking,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: Theme.of(context).primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Choose Vehicle Type',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for dotted line
class DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[400]!
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    
    const dashHeight = 3;
    const dashSpace = 3;
    double startY = 0;
    
    while (startY < size.height) {
      canvas.drawLine(
        Offset(0, startY),
        Offset(0, startY + dashHeight),
        paint,
      );
      startY += dashHeight + dashSpace;
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
