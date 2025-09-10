import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';

class LocationSearchScreen extends StatefulWidget {
  const LocationSearchScreen({super.key});

  @override
  State<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _pickupFocus = FocusNode();
  final FocusNode _destinationFocus = FocusNode();
  
  bool _isPickupFocused = true;
  String? _currentLocationName;
  Position? _currentPosition;
  
  // Sample locations for demo
  final List<Map<String, dynamic>> _sampleLocations = [
    {'name': 'Karachi Airport', 'address': 'Jinnah International Airport, Karachi', 'lat': 24.9056, 'lng': 67.1608},
    {'name': 'Saddar Market', 'address': 'Saddar Town, Karachi', 'lat': 24.8607, 'lng': 67.0011},
    {'name': 'Clifton Beach', 'address': 'Clifton, Karachi', 'lat': 24.8138, 'lng': 67.0300},
    {'name': 'Port Grand', 'address': 'West Wharf, Karachi', 'lat': 24.8419, 'lng': 66.9750},
    {'name': 'Lucky One Mall', 'address': 'Main Rashid Minhas Road, Karachi', 'lat': 24.9180, 'lng': 67.0971},
    {'name': 'Ocean Mall', 'address': 'Clifton, Karachi', 'lat': 24.8138, 'lng': 67.0282},
    {'name': 'Dolmen Mall Clifton', 'address': 'Marine Drive, Clifton, Karachi', 'lat': 24.8025, 'lng': 67.0308},
  ];
  
  List<Map<String, dynamic>> _filteredLocations = [];
  
  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _filteredLocations = _sampleLocations;
    
    _pickupFocus.addListener(() {
      setState(() {
        _isPickupFocused = _pickupFocus.hasFocus;
      });
    });
    
    _destinationFocus.addListener(() {
      setState(() {
        _isPickupFocused = !_destinationFocus.hasFocus;
      });
    });
  }
  
  Future<void> _getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _currentLocationName = 'Location services disabled';
        });
        return;
      }
      
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _currentLocationName = 'Location permission denied';
          });
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _currentLocationName = 'Location permission permanently denied';
        });
        return;
      }
      
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
        _currentLocationName = 'Current Location';
        _pickupController.text = 'Current Location';
      });
    } catch (e) {
      setState(() {
        _currentLocationName = 'Unable to get location';
      });
    }
  }
  
  void _filterLocations(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredLocations = _sampleLocations;
      } else {
        _filteredLocations = _sampleLocations.where((location) {
          return location['name'].toLowerCase().contains(query.toLowerCase()) ||
                 location['address'].toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }
  
  Map<String, dynamic>? _selectedPickupLocation;
  Map<String, dynamic>? _selectedDestinationLocation;
  
  void _selectLocation(Map<String, dynamic> location) {
    setState(() {
      if (_isPickupFocused) {
        _pickupController.text = location['name'];
        _selectedPickupLocation = location;
        // Auto-focus destination field
        FocusScope.of(context).requestFocus(_destinationFocus);
      } else {
        _destinationController.text = location['name'];
        _selectedDestinationLocation = location;
      }
    });
  }
  
  void _proceedToRideOptions() {
    if (_pickupController.text.isEmpty || _destinationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both pickup and destination locations'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Pass location data to route preview screen
    context.push(
      '/route-preview',
      extra: {
        'pickup': _pickupController.text,
        'destination': _destinationController.text,
        'pickupLat': _selectedPickupLocation?['lat'] ?? _currentPosition?.latitude ?? 24.8607,
        'pickupLng': _selectedPickupLocation?['lng'] ?? _currentPosition?.longitude ?? 67.0011,
        'destLat': _selectedDestinationLocation?['lat'] ?? 24.8138,
        'destLng': _selectedDestinationLocation?['lng'] ?? 67.0300,
      },
    );
  }
  
  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
    _pickupFocus.dispose();
    _destinationFocus.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Set Pickup & Destination'),
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
          // Location inputs
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Pickup location
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _pickupController,
                        focusNode: _pickupFocus,
                        onChanged: _filterLocations,
                        decoration: InputDecoration(
                          hintText: 'Pickup location',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: _isPickupFocused ? Theme.of(context).primaryColor : Colors.grey[300]!,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Theme.of(context).primaryColor,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          suffixIcon: _pickupController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      _pickupController.clear();
                                    });
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
                // Dotted line connector
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  height: 30,
                  child: CustomPaint(
                    painter: DottedLinePainter(),
                  ),
                ),
                // Destination
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _destinationController,
                        focusNode: _destinationFocus,
                        onChanged: _filterLocations,
                        decoration: InputDecoration(
                          hintText: 'Where to?',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: !_isPickupFocused ? Theme.of(context).primaryColor : Colors.grey[300]!,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: Theme.of(context).primaryColor,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          suffixIcon: _destinationController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      _destinationController.clear();
                                    });
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Current location button
          if (_currentLocationName != null && _pickupFocus.hasFocus)
            Container(
              width: double.infinity,
              color: Colors.white,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _pickupController.text = _currentLocationName!;
                      _selectedPickupLocation = {
                        'name': _currentLocationName!,
                        'lat': _currentPosition?.latitude ?? 24.8607,
                        'lng': _currentPosition?.longitude ?? 67.0011,
                      };
                      FocusScope.of(context).requestFocus(_destinationFocus);
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.my_location, color: Theme.of(context).primaryColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentLocationName!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              if (_currentPosition != null)
                                Text(
                                  'Lat: ${_currentPosition!.latitude.toStringAsFixed(4)}, Lng: ${_currentPosition!.longitude.toStringAsFixed(4)}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          
          // Suggestions list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _filteredLocations.length,
              itemBuilder: (context, index) {
                final location = _filteredLocations[index];
                return Container(
                  color: Colors.white,
                  margin: const EdgeInsets.only(bottom: 1),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _selectLocation(location),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(
                                Icons.location_on,
                                color: Colors.grey[600],
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    location['name'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    location['address'],
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
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
          
          // Continue button
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
              child: ElevatedButton(
                onPressed: _proceedToRideOptions,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: Theme.of(context).primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Show Route',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
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