import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../core/services/map_service.dart';
import '../../core/models/location_model.dart';
import '../providers/location_provider.dart';

class MapWidget extends ConsumerStatefulWidget {
  final LocationModel? initialLocation;
  final List<LocationModel> markers;
  final Function(LatLng)? onMapTap;
  final Function(LocationModel)? onLocationSelected;
  final bool showCurrentLocation;
  final double height;

  const MapWidget({
    super.key,
    this.initialLocation,
    this.markers = const [],
    this.onMapTap,
    this.onLocationSelected,
    this.showCurrentLocation = true,
    this.height = double.infinity,
  });

  @override
  ConsumerState<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends ConsumerState<MapWidget> {
  MapLibreMapController? _mapController;
  final MapService _mapService = MapService();
  bool _isMapReady = false;

  @override
  Widget build(BuildContext context) {
    final currentLocationAsync = ref.watch(currentLocationProvider);
    final hasLocationPermission = ref.watch(locationPermissionProvider);

    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          // Map
          MapLibreMap(
            styleString: _getMapStyle(),
            initialCameraPosition: _getInitialCameraPosition(),
            onMapCreated: _onMapCreated,
            onMapClick: _onMapClick,
            myLocationEnabled: widget.showCurrentLocation && hasLocationPermission,
            myLocationTrackingMode: MyLocationTrackingMode.tracking,
            compassEnabled: true,
            // Note: Logo and attribution hiding may need different approach in newer versions
          ),

          // Loading overlay
          if (!_isMapReady)
            Container(
              color: Colors.grey[100],
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Loading map...',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Current location button
          if (widget.showCurrentLocation)
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton.small(
                onPressed: _goToCurrentLocation,
                backgroundColor: Colors.white,
                child: const Icon(
                  Icons.my_location,
                  color: Colors.blue,
                ),
              ),
            ),

          // Location permission prompt
          if (!hasLocationPermission)
            Positioned.fill(
              child: Container(
                color: Colors.white.withOpacity(0.9),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.location_off,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Location Permission Required',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'We need access to your location to show nearby drivers and provide accurate pickup information.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _requestLocationPermission,
                          child: const Text('Enable Location'),
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

  String _getMapStyle() {
    // Use MapTiler with your API key
    return 'https://api.maptiler.com/maps/streets-v2/style.json?key=NbLuKHhFj26YAHTUNrOW';
  }

  CameraPosition _getInitialCameraPosition() {
    if (widget.initialLocation != null) {
      return _mapService.createInitialCameraPosition(
        latitude: widget.initialLocation!.latitude,
        longitude: widget.initialLocation!.longitude,
      );
    }

    // Default to a central location (you can change this)
    return _mapService.createInitialCameraPosition(
      latitude: 37.7749, // San Francisco coordinates as default
      longitude: -122.4194,
    );
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    _mapService.initializeController(controller);
    
    setState(() {
      _isMapReady = true;
    });

    // Add initial markers
    _addInitialMarkers();
  }

  void _onMapClick(dynamic point, LatLng latLng) {
    if (widget.onMapTap != null) {
      widget.onMapTap!(latLng);
    }
  }

  void _addInitialMarkers() {
    // Add markers for provided locations
    for (final location in widget.markers) {
      _mapService.addMarker(
        markerId: 'marker-${location.hashCode}',
        latitude: location.latitude,
        longitude: location.longitude,
      );
    }
  }

  Future<void> _goToCurrentLocation() async {
    final currentLocationAsync = ref.read(currentLocationProvider);
    
    currentLocationAsync.when(
      data: (location) {
        if (location != null) {
          _mapService.moveCameraToLocation(location);
        }
      },
      loading: () {
        // Show loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Getting your location...')),
        );
      },
      error: (error, stack) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $error')),
        );
      },
    );
  }

  Future<void> _requestLocationPermission() async {
    final notifier = ref.read(locationPermissionProvider.notifier);
    final granted = await notifier.requestPermission();
    
    if (granted) {
      // Refresh current location
      ref.read(currentLocationProvider.notifier).refreshLocation();
    }
  }
}
