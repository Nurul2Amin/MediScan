import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:prescription_scanner/data/models/osm_pharmacy.dart';

class OsmPharmacyService {
  // Simple in-memory cache to avoid spamming the API with the same request
  final Map<String, List<OsmPharmacy>> _cache = {};

  Future<List<OsmPharmacy>> fetchNearbyPharmacies(double lat, double lng, {int radiusMeters = 5000}) async {
    final cacheKey = '$lat,$lng,$radiusMeters';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    // Overpass API Query
    // [out:json]; node(around:radius, lat, lon)[amenity=pharmacy]; out;
    final query = """
    [out:json][timeout:25];
    (
      node["amenity"="pharmacy"](around:$radiusMeters, $lat, $lng);
      way["amenity"="pharmacy"](around:$radiusMeters, $lat, $lng);
      relation["amenity"="pharmacy"](around:$radiusMeters, $lat, $lng);
    );
    out center;
    """;

    final url = Uri.parse('https://overpass-api.de/api/interpreter');

    try {
      final response = await http.post(
        url,
        body: {'data': query},
        headers: {
          // It's good practice to set a User-Agent for Overpass API
          'User-Agent': 'MediScanApp/1.0', 
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final elements = data['elements'] as List;

        final pharmacies = elements.map((e) {
          // For ways/relations, 'center' holds details, for nodes top level has lat/lon
          final lat = e['lat'] ?? e['center']?['lat'];
          final lon = e['lon'] ?? e['center']?['lon'];
          
          if (lat == null || lon == null) return null;

          // Merge center into main object for uniform parsing if needed, 
          // or just handle here. The model expects lat/lon at top level or handle creation here.
          // Let's create the map for model here to handle the geometry difference.
          
          final Map<String, dynamic> elementJson = Map.from(e);
          if (elementJson['lat'] == null && elementJson['center'] != null) {
            elementJson['lat'] = elementJson['center']['lat'];
            elementJson['lon'] = elementJson['center']['lon'];
          }

          return OsmPharmacy.fromJson(elementJson);
        }).whereType<OsmPharmacy>().toList();

        _cache[cacheKey] = pharmacies;
        return pharmacies;
      } else {
        // print('Error fetching OSM data: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      // print('Exception fetching OSM data: $e');
      return [];
    }
  }
}
