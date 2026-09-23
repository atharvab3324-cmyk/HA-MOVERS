class FareCalculator {
  /// Calculates the final fare for a trip.
  ///
  /// Formula:
  /// F = Max(B, B + (D × Rd) + (T × Rt)) × S
  ///
  /// B  = Base fare
  /// D  = Distance in kilometers
  /// Rd = Rate per kilometer
  /// T  = Time in minutes
  /// Rt = Rate per minute
  /// S  = Service multiplier
  static double calculateFare({
    required double baseFare,
    required double distanceKm,
    required double ratePerKm,
    required double timeMinutes,
    required double ratePerMinute,
    required double serviceMultiplier,
  }) {
    final distanceCharge = distanceKm * ratePerKm;
    final timeCharge = timeMinutes * ratePerMinute;

    final calculatedFare = baseFare + distanceCharge + timeCharge;

    final minimumFare = baseFare;

    final fareBeforeMultiplier = calculatedFare > minimumFare
        ? calculatedFare
        : minimumFare;

    final finalFare = fareBeforeMultiplier * serviceMultiplier;

    return _roundToTwoDecimals(finalFare);
  }

  static double _roundToTwoDecimals(double value) {
    return double.parse(value.toStringAsFixed(2));
  }
}
