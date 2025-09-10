class LocationModel {
  final double latitude;
  final double longitude;
  final String address;
  final DateTime timestamp;
  final String? name; // For saved locations like "Home", "Work"
  final String? placeId; // For map integration

  const LocationModel({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.timestamp,
    this.name,
    this.placeId,
  });

  /// Create from JSON
  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      latitude: json['latitude']?.toDouble() ?? 0.0,
      longitude: json['longitude']?.toDouble() ?? 0.0,
      address: json['address'] ?? '',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      name: json['name'],
      placeId: json['placeId'],
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'timestamp': timestamp.toIso8601String(),
      'name': name,
      'placeId': placeId,
    };
  }

  /// Create a copy with updated fields
  LocationModel copyWith({
    double? latitude,
    double? longitude,
    String? address,
    DateTime? timestamp,
    String? name,
    String? placeId,
  }) {
    return LocationModel(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      timestamp: timestamp ?? this.timestamp,
      name: name ?? this.name,
      placeId: placeId ?? this.placeId,
    );
  }

  /// Check if two locations are equal
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is LocationModel &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.address == address &&
        other.name == name &&
        other.placeId == placeId;
  }

  @override
  int get hashCode {
    return latitude.hashCode ^
        longitude.hashCode ^
        address.hashCode ^
        name.hashCode ^
        placeId.hashCode;
  }

  @override
  String toString() {
    return 'LocationModel(latitude: $latitude, longitude: $longitude, address: $address, name: $name)';
  }

  /// Get a short display address (first part before comma)
  String get shortAddress {
    if (address.contains(',')) {
      return address.split(',')[0].trim();
    }
    return address;
  }

  /// Check if this is a valid location
  bool get isValid {
    return latitude != 0.0 && longitude != 0.0 && address.isNotEmpty;
  }
}
