import 'package:dio/dio.dart';

/// OSM Nominatim + Overpass orqali joylashuv / yaqin joylar.
/// Google Maps API kaliti talab qilinmaydi.
class PlacesService {
  PlacesService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 15),
                headers: const {
                  'User-Agent': 'AnyLang/1.0 (https://anylang.uz; support@anylang.uz)',
                  'Accept-Language': 'uz,ru,en',
                },
              ),
            );

  final Dio _dio;

  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final res = await _dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': latitude,
          'lon': longitude,
          'format': 'jsonv2',
          'zoom': 18,
          'addressdetails': 1,
        },
      );
      final data = res.data;
      if (data is! Map) return null;
      final name = data['name']?.toString().trim();
      if (name != null && name.isNotEmpty) return name;
      final display = data['display_name']?.toString().trim();
      if (display == null || display.isEmpty) return null;
      final parts = display.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
      return parts.take(2).join(', ');
    } catch (_) {
      return null;
    }
  }

  Future<List<NearbyPlace>> nearbyPlaces({
    required double latitude,
    required double longitude,
    int radiusMeters = 900,
    int limit = 20,
  }) async {
    final query = '''
[out:json][timeout:15];
(
  nwr["name"]["amenity"](around:$radiusMeters,$latitude,$longitude);
  nwr["name"]["shop"](around:$radiusMeters,$latitude,$longitude);
  nwr["name"]["tourism"](around:$radiusMeters,$latitude,$longitude);
  nwr["name"]["leisure"](around:$radiusMeters,$latitude,$longitude);
);
out center $limit;
''';
    try {
      final res = await _dio.post(
        'https://overpass-api.de/api/interpreter',
        data: query,
        options: Options(
          contentType: 'text/plain',
          responseType: ResponseType.json,
        ),
      );
      final elements = (res.data is Map) ? res.data['elements'] : null;
      if (elements is! List) return const [];

      final out = <NearbyPlace>[];
      for (final raw in elements) {
        if (raw is! Map) continue;
        final tags = Map<String, dynamic>.from(raw['tags'] as Map? ?? {});
        final name = tags['name']?.toString().trim();
        if (name == null || name.isEmpty) continue;

        double? lat;
        double? lon;
        if (raw['lat'] is num && raw['lon'] is num) {
          lat = (raw['lat'] as num).toDouble();
          lon = (raw['lon'] as num).toDouble();
        } else if (raw['center'] is Map) {
          final c = Map<String, dynamic>.from(raw['center'] as Map);
          lat = (c['lat'] as num?)?.toDouble();
          lon = (c['lon'] as num?)?.toDouble();
        }
        if (lat == null || lon == null) continue;

        final street = [
          tags['addr:street'],
          tags['addr:housenumber'],
        ].whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).join(' ');
        final city = (tags['addr:city'] ?? tags['addr:town'] ?? tags['addr:suburb'])
            ?.toString()
            .trim();
        final address = [
          if (street.isNotEmpty) street,
          if (city != null && city.isNotEmpty) city,
        ].join(', ');

        final kind = (tags['amenity'] ?? tags['shop'] ?? tags['tourism'] ?? tags['leisure'])
                ?.toString() ??
            'place';

        out.add(
          NearbyPlace(
            name: name,
            address: address.isNotEmpty ? address : null,
            latitude: lat,
            longitude: lon,
            kind: kind,
          ),
        );
        if (out.length >= limit) break;
      }
      return out;
    } catch (_) {
      return const [];
    }
  }
}

class NearbyPlace {
  final String name;
  final String? address;
  final double latitude;
  final double longitude;
  final String kind;

  const NearbyPlace({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
    this.kind = 'place',
  });
}
