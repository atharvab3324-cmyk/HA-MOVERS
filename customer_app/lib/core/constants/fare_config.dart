class VehicleFareConfig {
  final String vehicleType;
  final double baseFare;
  final double? minRatePerKm;
  final double? maxRatePerKm;
  final double? ratePerMinute;
  final bool dynamicPricing;

  const VehicleFareConfig({
    required this.vehicleType,
    required this.baseFare,
    this.minRatePerKm,
    this.maxRatePerKm,
    this.ratePerMinute,
    required this.dynamicPricing,
  });
}

class FareConfig {
  static const VehicleFareConfig twoWheeler = VehicleFareConfig(
    vehicleType: '2-Wheeler',
    baseFare: 48.0,
    minRatePerKm: 7.2,
    maxRatePerKm: 11.6,
    ratePerMinute: null,
    dynamicPricing: true,
  );

  static const VehicleFareConfig miniTruck = VehicleFareConfig(
    vehicleType: 'Mini Truck',
    baseFare: 205.0,
    minRatePerKm: 28.0,
    maxRatePerKm: 28.0,
    ratePerMinute: 1.0,
    dynamicPricing: true,
  );

  static const VehicleFareConfig flatbed = VehicleFareConfig(
    vehicleType: 'Flatbed',
    baseFare: 1500.0,
    minRatePerKm: 70.0,
    maxRatePerKm: 100.0,
    ratePerMinute: 3.0,
    dynamicPricing: true,
  );

  static VehicleFareConfig forVehicle(String vehicleType) {
    switch (vehicleType) {
      case '2-Wheeler':
        return twoWheeler;

      case 'Mini Truck':
        return miniTruck;

      case 'Flatbed':
        return flatbed;

      default:
        throw ArgumentError('Unknown vehicle type: $vehicleType');
    }
  }
}
