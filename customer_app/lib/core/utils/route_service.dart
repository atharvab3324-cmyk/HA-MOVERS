import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteService {
  static Future<RouteResult?> getRoute({
    required LatLng pickup,
    required LatLng drop,
  }) async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${pickup.longitude},${pickup.latitude};'
        '${drop.longitude},${drop.latitude}'
        '?overview=false',
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['code'] != 'Ok') {
        return null;
      }

      final routes = data['routes'] as List<dynamic>;

      if (routes.isEmpty) {
        return null;
      }

      final route = routes.first as Map<String, dynamic>;

      final distanceMeters = (route['distance'] as num).toDouble();
      final durationSeconds = (route['duration'] as num).toDouble();

      return RouteResult(
        distanceKm: distanceMeters / 1000,
        durationMinutes: durationSeconds / 60,
      );
    } catch (e) {
      return null;
    }
  }
}

class RouteResult {
  final double distanceKm;
  final double durationMinutes;

  const RouteResult({required this.distanceKm, required this.durationMinutes});
}
