import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/models/location_model.dart';
import '../../core/services/location_service.dart';

// Location service provider
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

// Current location provider
final currentLocationProvider = StateNotifierProvider<CurrentLocationNotifier, AsyncValue<LocationModel?>>((ref) {
  final locationService = ref.read(locationServiceProvider);
  return CurrentLocationNotifier(locationService);
});

// Pickup location provider
final pickupLocationProvider = StateProvider<LocationModel?>((ref) => null);

// Destination location provider
final destinationLocationProvider = StateProvider<LocationModel?>((ref) => null);

// Location permission status provider
final locationPermissionProvider = StateNotifierProvider<LocationPermissionNotifier, bool>((ref) {
  return LocationPermissionNotifier();
});

class CurrentLocationNotifier extends StateNotifier<AsyncValue<LocationModel?>> {
  final LocationService _locationService;

  CurrentLocationNotifier(this._locationService) : super(const AsyncValue.loading()) {
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      state = const AsyncValue.loading();
      final location = await _locationService.getCurrentPosition();
      state = AsyncValue.data(location);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refreshLocation() async {
    await _getCurrentLocation();
  }

  Future<void> updateLocation(LocationModel location) async {
    state = AsyncValue.data(location);
  }
}

class LocationPermissionNotifier extends StateNotifier<bool> {
  LocationPermissionNotifier() : super(false) {
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    try {
      final permission = await Geolocator.checkPermission();
      state = permission == LocationPermission.always || 
             permission == LocationPermission.whileInUse;
    } catch (e) {
      state = false;
    }
  }

  Future<bool> requestPermission() async {
    try {
      final permission = await Geolocator.requestPermission();
      final granted = permission == LocationPermission.always || 
                     permission == LocationPermission.whileInUse;
      state = granted;
      return granted;
    } catch (e) {
      state = false;
      return false;
    }
  }

  void updatePermissionStatus(bool granted) {
    state = granted;
  }
}
