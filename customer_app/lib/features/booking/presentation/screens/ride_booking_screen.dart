import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RideBookingScreen extends StatefulWidget {
  const RideBookingScreen({super.key});

  @override
  State<RideBookingScreen> createState() => _RideBookingScreenState();
}

class _RideBookingScreenState extends State<RideBookingScreen> {
  int _selectedVehicleIndex = 0;
  Map<String, dynamic>? _routeData;
  double _actualDistance = 5.5; // Default fallback
  int _actualDuration = 15; // Default fallback
  String _formattedDistance = '5.5km';
  String _formattedDuration = '15min';
  bool _hasActualRoute = false;
  
  // Vehicle types with base fares
  final List<Map<String, dynamic>> _vehicleTypes = [
    {
      'name': 'Economy',
      'icon': Icons.directions_car,
      'capacity': '4 seats',
      'baseFare': 150,
      'perKm': 15,
      'estimatedTime': '2-5 min',
      'description': 'Affordable rides for everyday travel',
    },
    {
      'name': 'Comfort',
      'icon': Icons.directions_car,
      'capacity': '4 seats',
      'baseFare': 200,
      'perKm': 20,
      'estimatedTime': '3-7 min',
      'description': 'Newer cars with more space',
    },
    {
      'name': 'Premium',
      'icon': Icons.local_taxi,
      'capacity': '4 seats',
      'baseFare': 300,
      'perKm': 30,
      'estimatedTime': '5-10 min',
      'description': 'High-end vehicles for special occasions',
    },
    {
      'name': 'XL',
      'icon': Icons.airport_shuttle,
      'capacity': '6 seats',
      'baseFare': 350,
      'perKm': 35,
      'estimatedTime': '7-12 min',
      'description': 'Larger vehicles for groups',
    },
  ];
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get route data passed from previous screen
    final extra = GoRouterState.of(context).extra;
    if (extra != null && extra is Map<String, dynamic>) {
      _routeData = extra;
      _setupRouteData();
    }
  }
  
  void _setupRouteData() {
    if (_routeData != null) {
      _hasActualRoute = _routeData!['hasRoute'] ?? false;
      _actualDistance = _routeData!['actualDistance']?.toDouble() ?? 5.5;
      _actualDuration = _routeData!['actualDuration']?.toInt() ?? 15;
      _formattedDistance = _routeData!['formattedDistance'] ?? '${_actualDistance.toStringAsFixed(1)}km';
      _formattedDuration = _routeData!['formattedDuration'] ?? '${_actualDuration}min';
      
      print('🚗 RideBooking - Distance: $_formattedDistance, Duration: $_formattedDuration, HasRoute: $_hasActualRoute');
    }
  }
  
  
  int _calculateFare(Map<String, dynamic> vehicle) {
    final baseFare = vehicle['baseFare'] as int;
    final perKm = vehicle['perKm'] as int;
    return baseFare + (perKm * _actualDistance).round();
  }
  
  void _proceedToHaggling() {
    final selectedVehicle = _vehicleTypes[_selectedVehicleIndex];
    final estimatedFare = _calculateFare(selectedVehicle);
    
    context.push(
      '/haggling',
      extra: {
        ..._routeData ?? {},
        'vehicleType': selectedVehicle['name'],
        'estimatedFare': estimatedFare,
        'actualDistance': _actualDistance,
        'actualDuration': _actualDuration,
        'hasActualRoute': _hasActualRoute,
        'selectedVehicle': selectedVehicle,
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Choose Your Ride'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Location summary
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 20,
                          color: Colors.grey[400],
                        ),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _routeData?['pickup'] ?? 'Pickup Location',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _routeData?['destination'] ?? 'Destination',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('Edit'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _hasActualRoute ? Colors.green[50] : Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _hasActualRoute ? Colors.green[200]! : Colors.blue[200]!,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _hasActualRoute ? Icons.route : Icons.straighten,
                        size: 16,
                        color: _hasActualRoute ? Colors.green[700] : Colors.blue[700],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$_formattedDistance • $_formattedDuration',
                        style: TextStyle(
                          color: _hasActualRoute ? Colors.green[700] : Colors.blue[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_hasActualRoute) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.verified,
                          size: 14,
                          color: Colors.green[700],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Vehicle options
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _vehicleTypes.length,
              itemBuilder: (context, index) {
                final vehicle = _vehicleTypes[index];
                final isSelected = _selectedVehicleIndex == index;
                final fare = _calculateFare(vehicle);
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: Colors.white,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedVehicleIndex = index;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSelected 
                                ? Theme.of(context).primaryColor 
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Vehicle icon
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? Theme.of(context).primaryColor.withOpacity(0.1)
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                vehicle['icon'],
                                size: 32,
                                color: isSelected 
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 16),
                            
                            // Vehicle details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        vehicle['name'],
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          vehicle['capacity'],
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    vehicle['description'],
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 14,
                                        color: Colors.grey[500],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        vehicle['estimatedTime'],
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            
                            // Fare
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'PKR $fare',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected 
                                        ? Theme.of(context).primaryColor
                                        : Colors.black,
                                  ),
                                ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _hasActualRoute ? 'Accurate' : 'Estimated',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: _hasActualRoute ? Colors.green[600] : Colors.grey[500],
                                          fontWeight: _hasActualRoute ? FontWeight.w600 : FontWeight.normal,
                                        ),
                                      ),
                                      if (_hasActualRoute) ...[
                                        const SizedBox(width: 2),
                                        Icon(
                                          Icons.verified,
                                          size: 10,
                                          color: Colors.green[600],
                                        ),
                                      ],
                                    ],
                                  ),
                              ],
                            ),
                            
                            // Selection indicator
                            if (isSelected)
                              Container(
                                margin: const EdgeInsets.only(left: 12),
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Payment method and continue button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Payment method selector
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.money, color: Colors.green[600]),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Cash Payment',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Continue button
                  ElevatedButton(
                    onPressed: _proceedToHaggling,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Find Drivers',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'PKR ${_calculateFare(_vehicleTypes[_selectedVehicleIndex])}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}