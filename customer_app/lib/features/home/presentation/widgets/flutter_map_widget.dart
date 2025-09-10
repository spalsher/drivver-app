import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../../../../core/services/routing_service.dart';
import '../../../../shared/themes/app_theme.dart';

// Custom TileProvider with proper headers for MapTiler API
class MapTilerTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = getTileUrl(coordinates, options);
    print('🗺️ MapTiler Tile Request: $url');
    
    // MapTiler requires EXACT User-Agent match - must match API key configuration
    final headers = <String, String>{
      'User-Agent': 'Drivrr/1.0.0', // EXACT match with MapTiler API key setting
      'Accept': 'image/png,image/jpeg,image/*,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
      'Connection': 'keep-alive',
    };
    
    print('🔑 Sending headers: $headers');
    
    return NetworkImage(url, headers: headers);
  }
}

class FlutterMapWidget extends StatefulWidget {
  final LatLng? pickupLocation;
  final LatLng? destinationLocation;
  final LatLng? driverLocation; // New parameter for driver tracking
  final Function(RouteResult)? onRouteCalculated;

  const FlutterMapWidget({
    super.key,
    this.pickupLocation,
    this.destinationLocation,
    this.driverLocation,
    this.onRouteCalculated,
  });

  @override
  State<FlutterMapWidget> createState() => _FlutterMapWidgetState();
}

class _FlutterMapWidgetState extends State<FlutterMapWidget> {
  final MapController _mapController = MapController();
  Position? _currentPosition;
  bool _isLoadingLocation = false;
  RouteResult? _currentRoute;
  bool _isCalculatingRoute = false;
  int _currentTileProvider = 0; // Start with NEW UNRESTRICTED MapTiler key!

  // Multiple MapTiler styles - based on MapTiler SDK JS documentation
  static const List<Map<String, String>> _tileProviders = [
    {
      'name': 'MapTiler Basic (MapLibre Style)',
      'url': 'https://api.maptiler.com/maps/basic-v2/{z}/{x}/{y}.png?key=Ngzdq59AXRfqPS7VYRAW',
      'description': 'Clean MapLibre GL style - perfect for apps',
    },
    {
      'name': 'MapTiler Streets',
      'url': 'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=Ngzdq59AXRfqPS7VYRAW',
      'description': 'Detailed street-level information',
    },
    {
      'name': 'MapTiler Bright',
      'url': 'https://api.maptiler.com/maps/bright-v2/{z}/{x}/{y}.png?key=Ngzdq59AXRfqPS7VYRAW',
      'description': 'High contrast bright style',
    },
    {
      'name': 'MapTiler Pastel',
      'url': 'https://api.maptiler.com/maps/pastel/{z}/{x}/{y}.png?key=Ngzdq59AXRfqPS7VYRAW',
      'description': 'Soft pastel colors - elegant look',
    },
    {
      'name': 'MapTiler Positron',
      'url': 'https://api.maptiler.com/maps/positron/{z}/{x}/{y}.png?key=Ngzdq59AXRfqPS7VYRAW',
      'description': 'Light minimal style for data viz',
    },
    {
      'name': 'MapTiler Voyager',
      'url': 'https://api.maptiler.com/maps/voyager-v2/{z}/{x}/{y}.png?key=Ngzdq59AXRfqPS7VYRAW',
      'description': 'Balanced style with good contrast',
    },
    {
      'name': 'MapTiler Topo',
      'url': 'https://api.maptiler.com/maps/topo-v2/{z}/{x}/{y}.png?key=Ngzdq59AXRfqPS7VYRAW',
      'description': 'Topographic style with terrain',
    },
    {
      'name': 'MapTiler Outdoor',
      'url': 'https://api.maptiler.com/maps/outdoor-v2/{z}/{x}/{y}.png?key=Ngzdq59AXRfqPS7VYRAW',
      'description': 'Perfect for hiking & outdoor apps',
    },
    {
      'name': 'MapTiler Satellite',
      'url': 'https://api.maptiler.com/maps/hybrid/{z}/{x}/{y}.jpg?key=Ngzdq59AXRfqPS7VYRAW',
      'description': 'Satellite imagery with labels',
    },
    {
      'name': 'OpenStreetMap (Fallback)',
      'url': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      'description': 'Open source fallback option',
    },
  ];

  @override
  void initState() {
    super.initState();
    print('🚗 FlutterMapWidget initState called');
    print('🚗 Initial pickup: ${widget.pickupLocation}');
    print('🚗 Initial destination: ${widget.destinationLocation}');
    
    _getCurrentLocation();
    
    // ALWAYS trigger route calculation if both locations are provided
    if (widget.pickupLocation != null && widget.destinationLocation != null) {
      print('🚀 Both locations provided in initState - triggering route calculation immediately');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _calculateRoute();
      });
    }
  }

  @override
  void didUpdateWidget(FlutterMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    print('🔄 didUpdateWidget called');
    print('🔄 Old pickup: ${oldWidget.pickupLocation}');
    print('🔄 New pickup: ${widget.pickupLocation}');
    print('🔄 Old destination: ${oldWidget.destinationLocation}');
    print('🔄 New destination: ${widget.destinationLocation}');
    print('🔄 Old driver: ${oldWidget.driverLocation}');
    print('🔄 New driver: ${widget.driverLocation}');
    
    // Check if pickup or destination changed
    final pickupChanged = oldWidget.pickupLocation != widget.pickupLocation;
    final destinationChanged = oldWidget.destinationLocation != widget.destinationLocation;
    final driverChanged = oldWidget.driverLocation != widget.driverLocation;
    final hasValidLocations = widget.pickupLocation != null && widget.destinationLocation != null;
    
    print('📍 Pickup changed: $pickupChanged');
    print('📍 Destination changed: $destinationChanged');
    print('📍 Driver changed: $driverChanged');
    print('📍 Has valid locations: $hasValidLocations');
    
    if ((pickupChanged || destinationChanged) && hasValidLocations) {
      print('📍 Locations changed - triggering route calculation');
      _calculateRoute();
    } else if (hasValidLocations && _currentRoute == null) {
      print('📍 Valid locations but no route - forcing route calculation');
      _calculateRoute();
    } else if (driverChanged) {
      print('📍 Driver location changed - updating markers only');
      setState(() {}); // Trigger rebuild to update driver marker
    } else {
      print('📍 No route calculation needed');
    }
  }

  Future<void> _getCurrentLocation() async {
    if (_isLoadingLocation) return;

    setState(() {
      _isLoadingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
      });

      _mapController.move(
        LatLng(position.latitude, position.longitude),
        15.0,
      );
    } catch (e) {
      print('Error getting location: $e');
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _calculateRoute() async {
    print('🚗 _calculateRoute called');
    print('🚗 Pickup: ${widget.pickupLocation}');
    print('🚗 Destination: ${widget.destinationLocation}');
    
    if (widget.pickupLocation == null || widget.destinationLocation == null) {
      print('❌ Route calculation skipped - missing pickup or destination');
      return;
    }

    if (_isCalculatingRoute) {
      print('⏳ Route calculation already in progress');
      return;
    }

    print('🚀 Starting route calculation...');
    setState(() {
      _isCalculatingRoute = true;
    });

    try {
      final routingService = RoutingService();
      
      print('🌐 Calling OSRM routing service...');
      final result = await routingService.getRoute(
        start: widget.pickupLocation!,
        end: widget.destinationLocation!,
      );

      print('✅ Route calculated successfully: ${result.points.length} points, ${result.formattedDistance}, ${result.formattedDuration}');

      setState(() {
        _currentRoute = result;
      });

      if (widget.onRouteCalculated != null) {
        print('📞 Calling onRouteCalculated callback');
        widget.onRouteCalculated!(result);
      }

      // Add a small delay before fitting to ensure UI is ready
      await Future.delayed(const Duration(milliseconds: 500));
      _fitMapToRoute();
    } catch (e) {
      print('❌ Error calculating route: $e');
    } finally {
      setState(() {
        _isCalculatingRoute = false;
      });
    }
  }

  void _fitMapToRoute() {
    if (_currentRoute == null || _currentRoute!.points.isEmpty) return;

    print('🎯 Fitting map to show complete route with ${_currentRoute!.points.length} points');
    
    // Create bounds from all route points
    final bounds = LatLngBounds.fromPoints(_currentRoute!.points);
    
    print('🗺️ Route bounds: SW(${bounds.southWest.latitude}, ${bounds.southWest.longitude}) NE(${bounds.northEast.latitude}, ${bounds.northEast.longitude})');
    
    // Calculate proper padding based on screen size and UI elements
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top + 200; // Search bar + quick actions
    final bottomPadding = 180.0; // Bottom container + navigation
    final sidePadding = 40.0; // Side margins
    
    // Fit camera with generous padding to show complete route
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: EdgeInsets.only(
          top: topPadding,
          bottom: bottomPadding,
          left: sidePadding,
          right: sidePadding,
        ),
        maxZoom: 16.0, // Prevent zooming in too much
        minZoom: 8.0,  // Prevent zooming out too much
      ),
    );
    
    print('✅ Map fitted to show complete route from start to finish');
  }

  List<Marker> _buildMarkers() {
    List<Marker> markers = [];

    // Current location marker
    if (_currentPosition != null) {
      markers.add(
        Marker(
          point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          width: 20,
          height: 20,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      );
    }

    // Pickup location marker
    if (widget.pickupLocation != null) {
      markers.add(
        Marker(
          point: widget.pickupLocation!,
          width: 30,
          height: 30,
          child: const Icon(
            Icons.location_on,
            color: Colors.green,
            size: 30,
          ),
        ),
      );
    }

    // Destination location marker
    if (widget.destinationLocation != null) {
      markers.add(
        Marker(
          point: widget.destinationLocation!,
          width: 30,
          height: 30,
          child: const Icon(
            Icons.location_on,
            color: Colors.red,
            size: 30,
          ),
        ),
      );
    }

    // Driver location marker (for real-time tracking)
    if (widget.driverLocation != null) {
      markers.add(
        Marker(
          point: widget.driverLocation!,
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primaryColor, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  offset: const Offset(0, 2),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              Icons.local_taxi,
              color: AppTheme.primaryColor,
              size: 20,
            ),
          ),
        ),
      );
    }

    return markers;
  }

  List<Polyline> _buildPolylines() {
    print('🛣️ _buildPolylines called');
    print('🛣️ _currentRoute: $_currentRoute');
    print('🛣️ Route points: ${_currentRoute?.points.length ?? 0}');
    
    if (_currentRoute == null || _currentRoute!.points.isEmpty) {
      print('❌ No route or empty points - returning empty polylines');
      return [];
    }

    print('✅ Creating enhanced polyline with ${_currentRoute!.points.length} points');
    return [
      // Background/border polyline for better visibility
      Polyline(
        points: _currentRoute!.points,
        strokeWidth: 8.0,
        color: Colors.white,
      ),
      // Main route polyline
      Polyline(
        points: _currentRoute!.points,
        strokeWidth: 5.0,
        color: AppTheme.primaryColor,
        gradientColors: [
          AppTheme.primaryColor,
          AppTheme.primaryColor.withOpacity(0.8),
          AppTheme.primaryColor,
        ],
      ),
    ];
  }

  void _switchTileProvider() {
    setState(() {
      _currentTileProvider = (_currentTileProvider + 1) % _tileProviders.length;
    });
    
    final providerName = _tileProviders[_currentTileProvider]['name']!;
    final isMapTiler = _currentTileProvider < 9;
    
    print('🔄 Switched to tile provider: $providerName (MapTiler: $isMapTiler)');
    print('🌐 URL Template: ${_tileProviders[_currentTileProvider]['url']}');
    
    // Show enhanced snackbar with description
    if (mounted) {
      final description = _tileProviders[_currentTileProvider]['description'] ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                providerName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                ),
              ],
            ],
          ),
          duration: const Duration(seconds: 4),
          backgroundColor: isMapTiler ? Colors.green.shade600 : Colors.blue.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentPosition != null
                ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                : const LatLng(-1.2921, 36.8219), // Nairobi default
            initialZoom: 13.0,
            minZoom: 3.0,
            maxZoom: 18.0,
          ),
          children: [
            // Dynamic tile layer with proper MapTiler headers
            TileLayer(
              urlTemplate: _tileProviders[_currentTileProvider]['url']!,
              userAgentPackageName: 'com.drivrr.customer',
              maxNativeZoom: 19,
              maxZoom: 19,
              // Use custom tile provider for MapTiler APIs (indices 0-8), standard for OSM (index 9)
              tileProvider: _currentTileProvider < 9 ? MapTilerTileProvider() : null,
              additionalOptions: const {
                'attribution': '© MapTiler © OpenStreetMap contributors',
              },
            ),
            PolylineLayer(
              polylines: _buildPolylines(),
            ),
            MarkerLayer(
              markers: _buildMarkers(),
            ),
          ],
        ),
        
        // Location button
        Positioned(
          bottom: 120,
          right: 16,
          child: FloatingActionButton(
            heroTag: "location_button",
            mini: true,
            onPressed: _isLoadingLocation ? null : _getCurrentLocation,
            backgroundColor: Theme.of(context).colorScheme.surface,
            foregroundColor: Theme.of(context).colorScheme.primary,
            child: _isLoadingLocation
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
          ),
        ),

        // Tile provider switch button (for debugging)
        Positioned(
          bottom: 180,
          right: 16,
          child: FloatingActionButton(
            mini: true,
            onPressed: _switchTileProvider,
            backgroundColor: Theme.of(context).colorScheme.secondary,
            foregroundColor: Theme.of(context).colorScheme.onSecondary,
            child: const Icon(Icons.layers),
          ),
        ),

        // Route calculation indicator
        if (_isCalculatingRoute)
          Positioned(
            top: 100,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Calculating route...',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}