import 'dart:math';

class RouteCalculator {
  /// Calculates the straight-line distance between two coordinates.
  ///
  /// This is a temporary fallback until Google Maps routing
  /// provides the actual road distance and travel time.
  static double calculateDistanceKm({
    required double pickupLatitude,
    required double pickupLongitude,
    required double dropLatitude,
    required double dropLongitude,
  }) {
    const double earthRadiusKm = 6371.0;

    final latitudeDifference = _degreesToRadians(dropLatitude - pickupLatitude);

    final longitudeDifference = _degreesToRadians(
      dropLongitude - pickupLongitude,
    );

    final pickupLatitudeRadians = _degreesToRadians(pickupLatitude);

    final dropLatitudeRadians = _degreesToRadians(dropLatitude);

    final a =
        (sin(latitudeDifference / 2) * sin(latitudeDifference / 2)) +
        (cos(pickupLatitudeRadians) *
            cos(dropLatitudeRadians) *
            sin(longitudeDifference / 2) *
            sin(longitudeDifference / 2));

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusKm * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * 3.141592653589793 / 180.0;
  }

  // Temporary placeholders.
  // These will be replaced by actual routing data later.
  static double estimateTimeMinutes(double distanceKm) {
    const double averageSpeedKmPerHour = 30.0;

    return (distanceKm / averageSpeedKmPerHour) * 60.0;
  }
}
