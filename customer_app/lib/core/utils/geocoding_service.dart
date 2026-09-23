import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class GeocodingService {
  static Future<LatLng?> searchLocation(String query) async {
    final trimmedQuery = query.trim();

    if (trimmedQuery.isEmpty) {
      return null;
    }

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'format': 'jsonv2',
        'q': trimmedQuery,
        'limit': '1',
        'addressdetails': '1',
      });

      final response = await http.get(
        uri,
        headers: {'User-Agent': 'HA-Movers/1.0'},
      );

      if (response.statusCode != 200) {
        return null;
      }

      final results = jsonDecode(response.body) as List<dynamic>;

      if (results.isEmpty) {
        return null;
      }

      final result = results.first as Map<String, dynamic>;

      final latitude = double.tryParse(result['lat']?.toString() ?? '');

      final longitude = double.tryParse(result['lon']?.toString() ?? '');

      if (latitude == null || longitude == null) {
        return null;
      }

      return LatLng(latitude, longitude);
    } catch (e) {
      return null;
    }
  }
}
