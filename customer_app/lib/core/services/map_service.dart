import 'package:maplibre_gl/maplibre_gl.dart';
import '../models/location_model.dart';
import '../constants/app_constants.dart';

class MapService {
  static final MapService _instance = MapService._internal();
  factory MapService() => _instance;
  MapService._internal();

  MapLibreMapController? _controller;
  
  /// Initialize map controller
  void initializeController(MapLibreMapController controller) {
    _controller = controller;
  }

  /// Get map style URL with API key
  String get mapStyleUrl {
    return '${AppConstants.mapStyle}?key=${AppConstants.mapTilerApiKey}';
  }

  /// Create initial camera position
  CameraPosition createInitialCameraPosition({
    required double latitude,
    required double longitude,
    double zoom = AppConstants.defaultZoom,
  }) {
    return CameraPosition(
      target: LatLng(latitude, longitude),
      zoom: zoom,
    );
  }

  /// Move camera to location
  Future<void> moveCamera({
    required double latitude,
    required double longitude,
    double? zoom,
    bool animate = true,
  }) async {
    if (_controller == null) return;

    final cameraUpdate = CameraUpdate.newLatLngZoom(
      LatLng(latitude, longitude),
      zoom ?? AppConstants.defaultZoom,
    );

    if (animate) {
      await _controller!.animateCamera(cameraUpdate);
    } else {
      await _controller!.moveCamera(cameraUpdate);
    }
  }

  /// Move camera to location model
  Future<void> moveCameraToLocation(LocationModel location, {double? zoom}) async {
    await moveCamera(
      latitude: location.latitude,
      longitude: location.longitude,
      zoom: zoom,
    );
  }

  /// Add marker to map
  Future<void> addMarker({
    required String markerId,
    required double latitude,
    required double longitude,
    String? iconImage,
    Map<String, dynamic>? data,
  }) async {
    if (_controller == null) return;

    await _controller!.addSymbol(
      SymbolOptions(
        geometry: LatLng(latitude, longitude),
        iconImage: iconImage ?? 'default-marker',
        iconSize: 1.0,
        textField: data?['title'],
        // textOffset: const [0.0, 2.0], // Comment out for now
      ),
      data ?? {},
    );
  }

  /// Add pickup marker
  Future<void> addPickupMarker(LocationModel location) async {
    await addMarker(
      markerId: 'pickup',
      latitude: location.latitude,
      longitude: location.longitude,
      iconImage: 'pickup-marker',
      data: {
        'type': 'pickup',
        'title': 'Pickup Location',
        'address': location.address,
      },
    );
  }

  /// Add destination marker
  Future<void> addDestinationMarker(LocationModel location) async {
    await addMarker(
      markerId: 'destination',
      latitude: location.latitude,
      longitude: location.longitude,
      iconImage: 'destination-marker',
      data: {
        'type': 'destination',
        'title': 'Destination',
        'address': location.address,
      },
    );
  }

  /// Add driver marker
  Future<void> addDriverMarker({
    required String driverId,
    required double latitude,
    required double longitude,
    double? heading,
    Map<String, dynamic>? driverData,
  }) async {
    await addMarker(
      markerId: 'driver-$driverId',
      latitude: latitude,
      longitude: longitude,
      iconImage: 'driver-marker',
      data: {
        'type': 'driver',
        'driverId': driverId,
        'heading': heading,
        ...?driverData,
      },
    );
  }

  /// Remove marker
  Future<void> removeMarker(String markerId) async {
    if (_controller == null) return;
    
    // Remove all symbols (markers) - MapLibre doesn't have direct marker removal
    await _controller!.clearSymbols();
  }

  /// Clear all markers
  Future<void> clearAllMarkers() async {
    if (_controller == null) return;
    await _controller!.clearSymbols();
  }

  /// Draw route between two points
  Future<void> drawRoute({
    required LocationModel start,
    required LocationModel end,
    String lineColor = '#2196F3',
    double lineWidth = 4.0,
  }) async {
    if (_controller == null) return;

    // Create route line
    await _controller!.addLine(
      LineOptions(
        geometry: [
          LatLng(start.latitude, start.longitude),
          LatLng(end.latitude, end.longitude),
        ],
        lineColor: lineColor,
        lineWidth: lineWidth,
        lineOpacity: 0.8,
      ),
    );
  }

  /// Clear route
  Future<void> clearRoute() async {
    if (_controller == null) return;
    await _controller!.clearLines();
  }

  /// Fit bounds to show multiple locations
  Future<void> fitBounds({
    required List<LocationModel> locations,
    double padding = 50.0,
  }) async {
    if (_controller == null || locations.isEmpty) return;

    if (locations.length == 1) {
      await moveCameraToLocation(locations.first);
      return;
    }

    // Calculate bounds
    double minLat = locations.first.latitude;
    double maxLat = locations.first.latitude;
    double minLng = locations.first.longitude;
    double maxLng = locations.first.longitude;

    for (final location in locations) {
      minLat = minLat < location.latitude ? minLat : location.latitude;
      maxLat = maxLat > location.latitude ? maxLat : location.latitude;
      minLng = minLng < location.longitude ? minLng : location.longitude;
      maxLng = maxLng > location.longitude ? maxLng : location.longitude;
    }

    // Add padding
    final latPadding = (maxLat - minLat) * 0.1;
    final lngPadding = (maxLng - minLng) * 0.1;

    final bounds = LatLngBounds(
      southwest: LatLng(minLat - latPadding, minLng - lngPadding),
      northeast: LatLng(maxLat + latPadding, maxLng + lngPadding),
    );

    await _controller!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, left: padding, top: padding, right: padding, bottom: padding),
    );
  }

  /// Get current map center
  Future<LatLng?> getMapCenter() async {
    if (_controller == null) return null;
    
    // Note: getCameraPosition might not be available in this version
    // Return null for now, implement when needed
    return null;
  }

  /// Convert LatLng to LocationModel
  LocationModel latLngToLocationModel(LatLng latLng, {String address = 'Unknown location'}) {
    return LocationModel(
      latitude: latLng.latitude,
      longitude: latLng.longitude,
      address: address,
      timestamp: DateTime.now(),
    );
  }

  /// Convert LocationModel to LatLng
  LatLng locationModelToLatLng(LocationModel location) {
    return LatLng(location.latitude, location.longitude);
  }

  /// Dispose map resources
  void dispose() {
    _controller = null;
  }
}
