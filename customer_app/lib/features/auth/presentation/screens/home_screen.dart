import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/fare_config.dart';
import '../../../../core/utils/fare_calculator.dart';
import '../../../../core/utils/route_calculator.dart';
import '../../../../core/utils/geocoding_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedService = 0;

  // OpenStreetMap demo position.
  // Real device/browser GPS will update this position.
  static const LatLng _mapCenter = LatLng(18.5204, 73.8567);
  GoogleMapController? _mapController;

  LatLng _currentMapLocation = _mapCenter;

  bool _isGettingLocation = false;

  LatLng? _dropMapLocation;

  // Location state
  String pickupLocation = 'Current Location';
  String dropLocation = 'Enter Drop Location';

  final List<Map<String, dynamic>> services = [
    {
      'name': '2-Wheeler',
      'image': 'assets/images/vehicles/two_wheeler.png',
      'fare': '161',
      'description': 'Small and quick deliveries',
    },
    {
      'name': 'Mini Truck',
      'image': 'assets/images/vehicles/mini_truck.png',
      'fare': '571',
      'description': 'Perfect for household moves',
    },
    {
      'name': 'Flatbed',
      'image': 'assets/images/vehicles/flatbed.png',
      'fare': '2610',
      'description': 'For large and heavy loads',
    },
  ];
  double _calculateServiceFare(String vehicleType) {
    if (_dropMapLocation == null) {
      return double.parse(
        services.firstWhere((service) => service['name'] == vehicleType)['fare']
            as String,
      );
    }

    final distance = RouteCalculator.calculateDistanceKm(
      pickupLatitude: _currentMapLocation.latitude,
      pickupLongitude: _currentMapLocation.longitude,
      dropLatitude: _dropMapLocation!.latitude,
      dropLongitude: _dropMapLocation!.longitude,
    );

    final time = RouteCalculator.estimateTimeMinutes(distance);

    final fareConfig = FareConfig.forVehicle(vehicleType);

    final ratePerKm =
        fareConfig.minRatePerKm != null && fareConfig.maxRatePerKm != null
        ? (fareConfig.minRatePerKm! + fareConfig.maxRatePerKm!) / 2
        : 0.0;

    final ratePerMinute = fareConfig.ratePerMinute ?? 0.0;

    return FareCalculator.calculateFare(
      baseFare: fareConfig.baseFare,
      distanceKm: distance,
      ratePerKm: ratePerKm,
      timeMinutes: time,
      ratePerMinute: ratePerMinute,
      serviceMultiplier: 1.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101828) : AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: Stack(
                children: [
                  _buildMapArea(context),
                  _buildLocationCard(context),
                  _buildServicePanel(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TOP BAR
  // ============================================================

  Widget _buildTopBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101828) : Colors.white,
        border: Border(
          bottom: BorderSide(color: isDark ? Colors.white10 : AppColors.border),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {},
            padding: EdgeInsets.zero,
            icon: Icon(
              Icons.menu_rounded,
              color: isDark ? Colors.white : AppColors.primaryText,
            ),
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              'HA Movers',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.primaryBlue,
              ),
            ),
          ),

          IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.notifications_none_rounded,
              color: isDark ? Colors.white : AppColors.primaryText,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MAP AREA
  // ============================================================

  Widget _buildMapArea(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // --------------------------------------------------------
        // OPENSTREETMAP
        // --------------------------------------------------------
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _currentMapLocation,
            zoom: 13.5,
          ),
          minMaxZoomPreference: const MinMaxZoomPreference(3, 19),
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          markers: {
            Marker(
              markerId: const MarkerId('current_location'),
              position: _currentMapLocation,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              ),
            ),
            if (_dropMapLocation != null)
              Marker(
                markerId: const MarkerId('drop_location'),
                position: _dropMapLocation!,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed,
                ),
              ),
          },
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
          },
        ),
        // --------------------------------------------------------
        // CURRENT LOCATION LABEL
        // --------------------------------------------------------
        Positioned(
          left: 18,
          top: 175,
          child: GestureDetector(
            onTap: _goToCurrentLocation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1D2939) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    size: 16,
                    color: AppColors.primaryBlue,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _isGettingLocation
                        ? 'Getting location...'
                        : 'Current location',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.primaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<String?> _getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'zoom': '18',
        'addressdetails': '1',
      });

      final response = await http.get(
        uri,
        headers: {'User-Agent': 'HA-Movers/1.0'},
      );

      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      return data['display_name'] as String?;
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // GET CURRENT GPS LOCATION
  // ============================================================

  Future<void> _goToCurrentLocation() async {
    if (_isGettingLocation) {
      return;
    }

    setState(() {
      _isGettingLocation = true;
    });

    try {
      // ----------------------------------------------------------
      // Android / iOS / desktop:
      // Check whether the operating system's location service
      // is enabled.
      //
      // Web:
      // The browser manages location availability and permission,
      // so we skip this check.
      // ----------------------------------------------------------
      if (!kIsWeb) {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();

        if (!serviceEnabled) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enable location services first.'),
            ),
          );

          return;
        }
      }

      // ----------------------------------------------------------
      // CHECK LOCATION PERMISSION
      // ----------------------------------------------------------
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission was denied.')),
        );

        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission is permanently denied. '
              'Please enable it in your browser/device settings.',
            ),
          ),
        );

        return;
      }

      // ----------------------------------------------------------
      // GET CURRENT POSITION
      // ----------------------------------------------------------
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final location = LatLng(position.latitude, position.longitude);

      final address = await _getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;

      setState(() {
        _currentMapLocation = location;
        pickupLocation =
            address ??
            '${position.latitude.toStringAsFixed(5)}, '
                '${position.longitude.toStringAsFixed(5)}';
      });

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: location, zoom: 15.0),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to get your location: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGettingLocation = false;
        });
      }
    }
  }

  // ============================================================
  // PICKUP + DROP LOCATION CARD
  // ============================================================

  Widget _buildLocationCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      top: 14,
      left: 14,
      right: 14,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1D2939) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isDark ? Colors.white12 : AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Route indicator
            SizedBox(
              width: 24,
              child: Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryBlue,
                      shape: BoxShape.circle,
                    ),
                  ),

                  Container(
                    width: 2,
                    height: 30,
                    color: isDark ? Colors.white24 : AppColors.border,
                  ),

                  const Icon(
                    Icons.location_on_rounded,
                    color: AppColors.error,
                    size: 18,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Locations
            Expanded(
              child: Column(
                children: [
                  _buildLocationRow(
                    context,
                    label: 'Pickup location',
                    value: pickupLocation,
                    isPickup: true,
                    onTap: _showPickupLocationDialog,
                  ),

                  const SizedBox(height: 10),

                  Divider(
                    height: 1,
                    color: isDark ? Colors.white12 : AppColors.border,
                  ),

                  const SizedBox(height: 10),

                  _buildLocationRow(
                    context,
                    label: 'Drop location',
                    value: dropLocation,
                    isPickup: false,
                    onTap: _showDropLocationDialog,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Swap button
            Material(
              color: isDark ? Colors.white10 : AppColors.lightBlue,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _swapLocations,
                child: const Padding(
                  padding: EdgeInsets.all(9),
                  child: Icon(
                    Icons.swap_vert_rounded,
                    color: AppColors.primaryBlue,
                    size: 21,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LOCATION ROW
  // ============================================================

  Widget _buildLocationRow(
    BuildContext context, {
    required String label,
    required String value,
    required bool isPickup,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.secondaryText,
                      fontSize: 11,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: value == 'Enter Drop Location'
                          ? AppColors.secondaryText
                          : null,
                    ),
                  ),
                ],
              ),
            ),

            Icon(
              isPickup ? Icons.my_location_rounded : Icons.search_rounded,
              size: 19,
              color: isPickup ? AppColors.primaryBlue : AppColors.secondaryText,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PICKUP LOCATION DIALOG
  // ============================================================

  void _showPickupLocationDialog() {
    final controller = TextEditingController(
      text: pickupLocation == 'Current Location' ? '' : pickupLocation,
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Enter Pickup Location',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: 'e.g. Hinjewadi, Pune',
              prefixIcon: const Icon(
                Icons.location_on_outlined,
                color: AppColors.primaryBlue,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primaryBlue,
                  width: 1.5,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),

            ElevatedButton(
              onPressed: () {
                final location = controller.text.trim();

                if (location.isEmpty) {
                  return;
                }

                setState(() {
                  pickupLocation = location;
                });

                Navigator.of(dialogContext).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Save',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // DROP LOCATION DIALOG
  // ============================================================

  void _showDropLocationDialog() {
    final controller = TextEditingController(
      text: dropLocation == 'Enter Drop Location' ? '' : dropLocation,
    );

    bool isSearching = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text(
                'Enter Drop Location',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              content: TextField(
                controller: controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: 'e.g. Pune Railway Station',
                  prefixIcon: const Icon(
                    Icons.location_on_outlined,
                    color: AppColors.primaryBlue,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primaryBlue,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSearching
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSearching
                      ? null
                      : () async {
                          final location = controller.text.trim();

                          if (location.isEmpty) {
                            return;
                          }

                          setDialogState(() {
                            isSearching = true;
                          });

                          final coordinates =
                              await GeocodingService.searchLocation(location);

                          if (!context.mounted) {
                            return;
                          }

                          if (coordinates == null) {
                            setDialogState(() {
                              isSearching = false;
                            });

                            if (!mounted) {
                              return;
                            }

                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Location not found. Try a more specific place.',
                                ),
                              ),
                            );

                            return;
                          }

                          setState(() {
                            dropLocation = location;
                            _dropMapLocation = coordinates;
                          });

                          _mapController?.animateCamera(
                            CameraUpdate.newCameraPosition(
                              CameraPosition(target: coordinates, zoom: 15.0),
                            ),
                          );

                          Navigator.of(dialogContext).pop();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: isSearching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // SWAP LOCATIONS
  // ============================================================

  void _swapLocations() {
    if (dropLocation == 'Enter Drop Location') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a drop location first.')),
      );
      return;
    }

    setState(() {
      final oldPickup = pickupLocation;
      pickupLocation = dropLocation;
      dropLocation = oldPickup;
    });
  }

  // ============================================================
  // SERVICE PANEL
  // ============================================================

  Widget _buildServicePanel(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 430),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF101828) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            const SizedBox(height: 14),

            Text(
              'Choose your service',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),

            const SizedBox(height: 12),

            ...List.generate(
              services.length,
              (index) => _buildServiceCard(context, index, services[index]),
            ),

            const SizedBox(height: 10),

            // Book Ride button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _bookRide,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: const Text(
                  'Book Ride',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SERVICE CARD
  // ============================================================

  Widget _buildServiceCard(
    BuildContext context,
    int index,
    Map<String, dynamic> service,
  ) {
    final isSelected = selectedService == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedService = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.lightBlue
              : isDark
              ? const Color(0xFF1D2939)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryBlue
                : isDark
                ? Colors.white12
                : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            // Vehicle image
            Container(
              width: 58,
              height: 58,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : AppColors.lightBlue,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Image.asset(
                service['image'] as String,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.local_shipping_outlined,
                    color: AppColors.primaryBlue,
                    size: 30,
                  );
                },
              ),
            ),

            const SizedBox(width: 14),

            // Service information
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service['name'] as String,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? AppColors.primaryText : null,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    service['description'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Fare and selection
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${_calculateServiceFare(service['name'] as String).toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: AppColors.primaryBlue,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 5),

                if (isSelected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.primaryBlue,
                    size: 20,
                  )
                else
                  Icon(
                    Icons.radio_button_unchecked_rounded,
                    color: isDark ? Colors.white38 : AppColors.disabled,
                    size: 20,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BOOK RIDE
  // ============================================================

  void _bookRide() {
    if (dropLocation == 'Enter Drop Location') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a drop location first.')),
      );
      return;
    }

    _showFareQuote();
  }

  // ============================================================
  // FARE QUOTE
  // ============================================================

  void _showFareQuote() {
    final selectedVehicle = services[selectedService];

    // Temporary values.
    // These will come from Google Maps routing later.
    final pickupLatitude = _currentMapLocation.latitude;
    final pickupLongitude = _currentMapLocation.longitude;

    if (_dropMapLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a drop location first.')),
      );
      return;
    }

    final dropLatitude = _dropMapLocation!.latitude;
    final dropLongitude = _dropMapLocation!.longitude;

    final estimatedDistance = RouteCalculator.calculateDistanceKm(
      pickupLatitude: pickupLatitude,
      pickupLongitude: pickupLongitude,
      dropLatitude: dropLatitude,
      dropLongitude: dropLongitude,
    );

    final estimatedTimeMinutes = RouteCalculator.estimateTimeMinutes(
      estimatedDistance,
    );

    final vehicleType = selectedVehicle['name'] as String;
    final fareConfig = FareConfig.forVehicle(vehicleType);

    // Use the midpoint of the published 2-Wheeler range for now.
    // Backend will eventually provide the dynamic rate.
    final double ratePerKm;

    if (fareConfig.minRatePerKm != null && fareConfig.maxRatePerKm != null) {
      ratePerKm = (fareConfig.minRatePerKm! + fareConfig.maxRatePerKm!) / 2;
    } else {
      // Temporary fallback for vehicle types whose rates
      // are not yet configured.
      ratePerKm = 0.0;
    }

    final double ratePerMinute = fareConfig.ratePerMinute ?? 0.0;

    final double estimatedFare = FareCalculator.calculateFare(
      baseFare: fareConfig.baseFare,
      distanceKm: estimatedDistance,
      ratePerKm: ratePerKm,
      timeMinutes: estimatedTimeMinutes,
      ratePerMinute: ratePerMinute,
      serviceMultiplier: 1.0,
    );

    final String fareText = estimatedFare > 0
        ? '₹${estimatedFare.toStringAsFixed(0)}'
        : 'Dynamic';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;

        return Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 700),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF172033) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HANDLE
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // HEADER
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Fare Estimate',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? Colors.white
                                : AppColors.primaryText,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                        },
                        icon: Icon(
                          Icons.close_rounded,
                          color: isDark
                              ? Colors.white70
                              : AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ROUTE
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF101828)
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withValues(
                                  alpha: 0.10,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.my_location_rounded,
                                color: AppColors.primaryBlue,
                                size: 15,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Pickup',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark
                                          ? Colors.white54
                                          : AppColors.secondaryText,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    pickupLocation,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.primaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        Padding(
                          padding: const EdgeInsets.only(
                            left: 13,
                            top: 4,
                            bottom: 4,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: 2,
                              height: 14,
                              color: isDark ? Colors.white24 : AppColors.border,
                            ),
                          ),
                        ),

                        Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.10),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.location_on_rounded,
                                color: AppColors.error,
                                size: 15,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Drop',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark
                                          ? Colors.white54
                                          : AppColors.secondaryText,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    dropLocation,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.primaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // SELECTED VEHICLE
                  Text(
                    'Selected vehicle',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.primaryText,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark ? Colors.white12 : AppColors.border,
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.lightBlue,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Image.asset(
                            selectedVehicle['image'] as String,
                            fit: BoxFit.contain,
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedVehicle['name'] as String,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.primaryText,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                selectedVehicle['description'] as String,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white60
                                      : AppColors.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primaryBlue,
                          size: 22,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // DISTANCE + FARE
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.lightBlue,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Estimated distance',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white60
                                      : AppColors.secondaryText,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${estimatedDistance.toStringAsFixed(0)} km',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.primaryText,
                                ),
                              ),
                            ],
                          ),
                        ),

                        Container(
                          width: 1,
                          height: 45,
                          color: isDark ? Colors.white24 : AppColors.border,
                        ),

                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Estimated fare',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.white60
                                        : AppColors.secondaryText,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  fareText,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'This is an estimated fare. Final fare may vary based on actual distance, time and trip conditions.',
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.4,
                      color: isDark ? Colors.white38 : AppColors.secondaryText,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // CONFIRM BOOKING
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        final bookingId = _generateBookingId();

                        Navigator.of(sheetContext).pop();

                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => _SearchingDriverScreen(
                              bookingId: bookingId,
                              vehicleName: selectedVehicle['name'] as String,
                              vehicleImage: selectedVehicle['image'] as String,
                              fare: fareText,
                              pickupLocation: pickupLocation,
                              dropLocation: dropLocation,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: const Text(
                        'Confirm Booking',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // BOOKING ID
  // ============================================================

  String _generateBookingId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

    return 'HA${timestamp.substring(timestamp.length - 8)}';
  }
}

// ================================================================
// SEARCHING / DRIVER ASSIGNED SCREEN
// ================================================================

class _SearchingDriverScreen extends StatefulWidget {
  final String bookingId;
  final String vehicleName;
  final String vehicleImage;
  final String fare;
  final String pickupLocation;
  final String dropLocation;

  const _SearchingDriverScreen({
    required this.bookingId,
    required this.vehicleName,
    required this.vehicleImage,
    required this.fare,
    required this.pickupLocation,
    required this.dropLocation,
  });

  @override
  State<_SearchingDriverScreen> createState() => _SearchingDriverScreenState();
}

class _SearchingDriverScreenState extends State<_SearchingDriverScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  Timer? _driverAssignmentTimer;

  bool _driverAssigned = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // ------------------------------------------------------------
    // SIMULATED DRIVER ASSIGNMENT
    // ------------------------------------------------------------
    // Later this will be replaced by the PHP backend / WebSocket
    // trip status update.
    _driverAssignmentTimer = Timer(const Duration(seconds: 5), _assignDriver);
  }

  void _assignDriver() {
    if (!mounted) {
      return;
    }

    setState(() {
      _driverAssigned = true;
    });

    _animationController.stop();
  }

  @override
  void dispose() {
    _driverAssignmentTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101828) : AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF101828) : Colors.white,
        foregroundColor: isDark ? Colors.white : AppColors.primaryText,
        title: Text(
          _driverAssigned ? 'Driver Assigned' : 'Booking Status',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: _driverAssigned
              ? _buildDriverAssignedView(context)
              : _buildSearchingView(context),
        ),
      ),
    );
  }

  // ============================================================
  // SEARCHING VIEW
  // ============================================================

  Widget _buildSearchingView(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      key: const ValueKey('searching'),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
      child: Column(
        children: [
          // ======================================================
          // SEARCHING ANIMATION
          // ======================================================

          SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    final scale = 1.0 + (_animationController.value * 0.25);

                    final opacity = 1.0 - _animationController.value;

                    return Container(
                      width: 150 * scale,
                      height: 150 * scale,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(
                          alpha: 0.12 * opacity,
                        ),
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                ),

                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryBlue.withValues(alpha: 0.30),
                        blurRadius: 25,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.search_rounded,
                    color: Colors.white,
                    size: 42,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ======================================================
          // STATUS
          // ======================================================
          Text(
            'Booking Confirmed',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.primaryText,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Searching for a driver',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryBlue,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'We are finding the nearest available driver for your trip.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: isDark ? Colors.white60 : AppColors.secondaryText,
            ),
          ),

          const SizedBox(height: 24),

          _buildBookingIdCard(
            context,
            status: 'SEARCHING',
            statusColor: AppColors.success,
          ),

          const SizedBox(height: 14),

          _buildTripDetailsCard(context),

          const SizedBox(height: 20),

          // ======================================================
          // SEARCHING INFORMATION
          // ======================================================
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.primaryBlue,
                  size: 20,
                ),

                SizedBox(width: 10),

                Expanded(
                  child: Text(
                    'Your booking is in SEARCHING_DRIVER status. Once a driver accepts the trip, their details will appear here.',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.45,
                      color: AppColors.primaryText,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          _buildCancelButton(context),
        ],
      ),
    );
  }

  // ============================================================
  // DRIVER ASSIGNED VIEW
  // ============================================================

  Widget _buildDriverAssignedView(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      key: const ValueKey('assigned'),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
      child: Column(
        children: [
          // ======================================================
          // SUCCESS ICON
          // ======================================================

          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 78,
                height: 78,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 46,
                ),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // ======================================================
          // STATUS
          // ======================================================
          Text(
            'Driver Assigned',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.primaryText,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            'Your driver is on the way',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.success,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Your trip has been accepted by a nearby driver.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: isDark ? Colors.white60 : AppColors.secondaryText,
            ),
          ),

          const SizedBox(height: 22),

          // ======================================================
          // BOOKING ID
          // ======================================================
          _buildBookingIdCard(
            context,
            status: 'DRIVER ASSIGNED',
            statusColor: AppColors.success,
          ),

          const SizedBox(height: 14),

          // ======================================================
          // DRIVER CARD
          // ======================================================
          _buildDriverCard(context),

          const SizedBox(height: 14),

          // ======================================================
          // VEHICLE CARD
          // ======================================================
          _buildAssignedVehicleCard(context),

          const SizedBox(height: 14),

          // ======================================================
          // TRIP DETAILS
          // ======================================================
          _buildTripDetailsCard(context),

          const SizedBox(height: 16),

          // ======================================================
          // DRIVER STATUS
          // ======================================================
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.directions_car_filled_rounded,
                    color: AppColors.success,
                    size: 21,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Driver is on the way',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.primaryText,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        'Estimated arrival: about 8 minutes',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.white60
                              : AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),

                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.success,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          _buildCancelButton(context),
        ],
      ),
    );
  }

  // ============================================================
  // BOOKING ID CARD
  // ============================================================

  Widget _buildBookingIdCard(
    BuildContext context, {
    required String status,
    required Color statusColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1D2939) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white12 : AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.confirmation_number_outlined,
            size: 20,
            color: isDark ? Colors.white70 : AppColors.secondaryText,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Booking ID',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white54 : AppColors.secondaryText,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  widget.bookingId,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: isDark ? Colors.white : AppColors.primaryText,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DRIVER CARD
  // ============================================================

  Widget _buildDriverCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1D2939) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white12 : AppColors.border),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your driver',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.primaryText,
            ),
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              // Driver avatar
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColors.lightBlue,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryBlue.withValues(alpha: 0.15),
                  ),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: AppColors.primaryBlue,
                  size: 32,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Rajesh Kumar',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.primaryText,
                            ),
                          ),
                        ),

                        const SizedBox(width: 7),

                        const Icon(
                          Icons.verified_rounded,
                          color: AppColors.primaryBlue,
                          size: 17,
                        ),
                      ],
                    ),

                    const SizedBox(height: 5),

                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: AppColors.warning,
                          size: 17,
                        ),

                        const SizedBox(width: 4),

                        Text(
                          '4.8',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : AppColors.primaryText,
                          ),
                        ),

                        const SizedBox(width: 8),

                        Text(
                          '•  Verified Driver',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? Colors.white60
                                : AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Divider(height: 1, color: isDark ? Colors.white12 : AppColors.border),

          const SizedBox(height: 14),

          // Call + Message
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Calling Rajesh Kumar...')),
                    );
                  },
                  icon: const Icon(Icons.call_rounded, size: 18),
                  label: const Text(
                    'Call',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryBlue,
                    side: const BorderSide(color: AppColors.primaryBlue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Opening chat with Rajesh Kumar...'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: const Text(
                    'Message',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ASSIGNED VEHICLE CARD
  // ============================================================

  Widget _buildAssignedVehicleCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1D2939) : Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: isDark ? Colors.white12 : AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Image.asset(
              widget.vehicleImage,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.local_shipping_outlined,
                  color: AppColors.primaryBlue,
                  size: 30,
                );
              },
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.vehicleName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.primaryText,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  'MH 12 AB 1234',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: isDark ? Colors.white70 : AppColors.primaryText,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  'Vehicle number',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white54 : AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),

          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: 23,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TRIP DETAILS CARD
  // ============================================================

  Widget _buildTripDetailsCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1D2939) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white12 : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trip details',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.primaryText,
            ),
          ),

          const SizedBox(height: 14),

          // Vehicle
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.lightBlue,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Image.asset(widget.vehicleImage, fit: BoxFit.contain),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.vehicleName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.primaryText,
                      ),
                    ),

                    const SizedBox(height: 3),

                    const Text(
                      'Selected vehicle',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),

              Text(
                widget.fare,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryBlue,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Divider(height: 1, color: isDark ? Colors.white12 : AppColors.border),

          const SizedBox(height: 16),

          // Pickup
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.my_location_rounded,
                color: AppColors.primaryBlue,
                size: 19,
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pickup',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? Colors.white54
                            : AppColors.secondaryText,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      widget.pickupLocation,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.primaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.only(left: 8, top: 5, bottom: 5),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 2,
                height: 18,
                color: isDark ? Colors.white24 : AppColors.border,
              ),
            ),
          ),

          // Drop
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_rounded,
                color: AppColors.error,
                size: 19,
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Drop',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? Colors.white54
                            : AppColors.secondaryText,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      widget.dropLocation,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.primaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CANCEL BUTTON
  // ============================================================

  Widget _buildCancelButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: () {
          _showCancelDialog(context);
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: const BorderSide(color: AppColors.error),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        child: const Text(
          'Cancel Booking',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  // ============================================================
  // CANCEL CONFIRMATION
  // ============================================================

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            'Cancel Booking?',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.primaryText,
            ),
          ),
          content: Text(
            'Are you sure you want to cancel this booking?',
            style: TextStyle(
              color: isDark ? Colors.white70 : AppColors.secondaryText,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Keep Booking'),
            ),

            ElevatedButton(
              onPressed: () {
                _driverAssignmentTimer?.cancel();

                Navigator.of(dialogContext).pop();
                Navigator.of(context).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Booking cancelled successfully.'),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Cancel Booking',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }
}
