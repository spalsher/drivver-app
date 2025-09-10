import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RoutingService {
  static const String _baseUrl = 'https://router.project-osrm.org/route/v1/driving';
  
  /// Calculate route between two points using OSRM (free routing service)
  Future<RouteResult> getRoute({
    required LatLng start,
    required LatLng end,
  }) async {
    print('🚀 RoutingService.getRoute() called');
    print('📍 Start: ${start.latitude}, ${start.longitude}');
    print('📍 End: ${end.latitude}, ${end.longitude}');
    
    try {
      final url = '$_baseUrl/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson';
      print('🗺️ Calculating route from ${start.latitude},${start.longitude} to ${end.latitude},${end.longitude}');
      print('🔗 OSRM URL: $url');
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📊 OSRM Response: ${data.toString().substring(0, 200)}...');
        
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry'];
          final coordinates = geometry['coordinates'] as List;
          
          // Convert coordinates to LatLng points
          final List<LatLng> routePoints = coordinates.map((coord) {
            return LatLng(coord[1].toDouble(), coord[0].toDouble());
          }).toList();
          
          // Extract distance and duration
          final distance = route['distance'].toDouble(); // in meters
          final duration = route['duration'].toDouble(); // in seconds
          
          print('✅ Route calculated: ${routePoints.length} points, ${(distance/1000).toStringAsFixed(1)}km, ${(duration/60).round()}min');
          
          return RouteResult(
            points: routePoints,
            distanceKm: distance / 1000,
            durationMinutes: duration / 60,
            instructions: 'Route calculated',
          );
        } else {
          print('❌ No routes found in OSRM response');
        }
      } else {
        print('❌ OSRM API error: ${response.statusCode} - ${response.body}');
      }
      
      // Fallback if no routes found
      final straightLineDistance = _calculateStraightLineDistance(start, end);
      return RouteResult(
        points: [start, end],
        distanceKm: straightLineDistance / 1000,
        durationMinutes: (straightLineDistance / 1000) * 3,
        instructions: 'Direct route',
      );
    } catch (e) {
      print('Error calculating route: $e');
      // Return a fallback straight-line route
      final straightLineDistance = _calculateStraightLineDistance(start, end);
      return RouteResult(
        points: [start, end], // Simple straight line
        distanceKm: straightLineDistance / 1000,
        durationMinutes: (straightLineDistance / 1000) * 3, // Estimate 3 minutes per km
        instructions: 'Direct route (fallback)',
      );
    }
  }
  
  /// Calculate straight-line distance using Haversine formula (fallback)
  static double _calculateStraightLineDistance(LatLng start, LatLng end) {
    const double earthRadius = 6371000; // Earth's radius in meters
    
    final double lat1Rad = start.latitude * (math.pi / 180);
    final double lat2Rad = end.latitude * (math.pi / 180);
    final double deltaLatRad = (end.latitude - start.latitude) * (math.pi / 180);
    final double deltaLngRad = (end.longitude - start.longitude) * (math.pi / 180);
    
    final double a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLngRad / 2) * math.sin(deltaLngRad / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  /// Format distance for display
  static String formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.round()}m';
    } else {
      final km = distanceInMeters / 1000;
      return '${km.toStringAsFixed(1)}km';
    }
  }
  
  /// Format duration for display
  static String formatDuration(double durationInSeconds) {
    final minutes = (durationInSeconds / 60).round();
    if (minutes < 60) {
      return '${minutes}min';
    } else {
      final hours = (minutes / 60).floor();
      final remainingMinutes = minutes % 60;
      return '${hours}h ${remainingMinutes}min';
    }
  }
}

class RouteResult {
  final List<LatLng> points;
  final double distanceKm;
  final double durationMinutes;
  final String instructions;

  RouteResult({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
    required this.instructions,
  });
  
  // Getters for backward compatibility
  double get distanceInKm => distanceKm;
  int get durationInMinutes => durationMinutes.round();
  
  String get formattedDistance {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()}m';
    } else {
      return '${distanceKm.toStringAsFixed(1)}km';
    }
  }
  
  String get formattedDuration {
    final minutes = durationMinutes.round();
    if (minutes < 60) {
      return '${minutes}min';
    } else {
      final hours = (minutes / 60).floor();
      final remainingMinutes = minutes % 60;
      return '${hours}h ${remainingMinutes}min';
    }
  }
}
