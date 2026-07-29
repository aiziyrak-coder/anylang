import 'package:dio/dio.dart';

import '../core/maps_config.dart';

/// Joylashuv / yaqin joylar.
/// Google Maps API kaliti bo‘lsa — Geocoding + Places; aks holda OSM fallback.
class PlacesService {
  PlacesService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 15),
                headers: const {
                  'User-Agent':
                      'AnyLang/1.0 (https://anylang.uz; support@anylang.uz)',
                  'Accept-Language': 'uz,ru,en',
                },
              ),
            );

  final Dio _dio;

  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    if (MapsConfig.isConfigured) {
      final google = await _googleReverse(latitude, longitude);
      if (google != null && google.isNotEmpty) return google;
    }
    return _nominatimReverse(latitude, longitude);
  }

  Future<List<NearbyPlace>> nearbyPlaces({
    required double latitude,
    required double longitude,
    int radiusMeters = 900,
    int limit = 20,
  }) async {
    if (MapsConfig.isConfigured) {
      final google = await _googleNearby(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
        limit: limit,
      );
      if (google.isNotEmpty) return google;
    }
    return _overpassNearby(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      limit: limit,
    );
  }

  Future<List<NearbyPlace>> searchPlaces({
    required String query,
    required double nearLat,
    required double nearLng,
    int limit = 15,
  }) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    if (MapsConfig.isConfigured) {
      final google = await _googleTextSearch(
        query: q,
        nearLat: nearLat,
        nearLng: nearLng,
        limit: limit,
      );
      if (google.isNotEmpty) return google;
    }
    return _nominatimSearch(
      query: q,
      nearLat: nearLat,
      nearLng: nearLng,
      limit: limit,
    );
  }

  Future<String?> _googleReverse(double lat, double lng) async {
    try {
      final res = await _dio.get(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {
          'latlng': '$lat,$lng',
          'key': MapsConfig.apiKey,
          'language': 'uz',
        },
      );
      final results = res.data is Map ? res.data['results'] : null;
      if (results is! List || results.isEmpty) return null;
      final first = results.first;
      if (first is! Map) return null;
      final comps = first['address_components'];
      if (comps is List) {
        String? name;
        String? route;
        String? locality;
        for (final raw in comps) {
          if (raw is! Map) continue;
          final types = (raw['types'] as List?)?.map((e) => '$e').toSet() ?? {};
          final longName = raw['long_name']?.toString();
          if (longName == null || longName.isEmpty) continue;
          if (types.contains('point_of_interest') ||
              types.contains('establishment') ||
              types.contains('premise')) {
            name ??= longName;
          }
          if (types.contains('route')) route ??= longName;
          if (types.contains('locality') ||
              types.contains('administrative_area_level_2')) {
            locality ??= longName;
          }
        }
        if (name != null && name.isNotEmpty) return name;
        final parts = [
          if (route != null && route.isNotEmpty) route,
          if (locality != null && locality.isNotEmpty) locality,
        ];
        if (parts.isNotEmpty) return parts.join(', ');
      }
      final formatted = first['formatted_address']?.toString().trim();
      if (formatted == null || formatted.isEmpty) return null;
      return formatted.split(',').take(2).map((e) => e.trim()).join(', ');
    } catch (_) {
      return null;
    }
  }

  Future<List<NearbyPlace>> _googleNearby({
    required double latitude,
    required double longitude,
    required int radiusMeters,
    required int limit,
  }) async {
    try {
      final res = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json',
        queryParameters: {
          'location': '$latitude,$longitude',
          'radius': radiusMeters,
          'key': MapsConfig.apiKey,
          'language': 'uz',
        },
      );
      final results = res.data is Map ? res.data['results'] : null;
      if (results is! List) return const [];
      final out = <NearbyPlace>[];
      for (final raw in results) {
        if (raw is! Map) continue;
        final name = raw['name']?.toString().trim();
        if (name == null || name.isEmpty) continue;
        final geo = raw['geometry'];
        final loc = geo is Map ? geo['location'] : null;
        if (loc is! Map) continue;
        final lat = (loc['lat'] as num?)?.toDouble();
        final lng = (loc['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        final types = (raw['types'] as List?)?.map((e) => '$e').toList() ?? [];
        out.add(
          NearbyPlace(
            name: name,
            address: raw['vicinity']?.toString(),
            latitude: lat,
            longitude: lng,
            kind: types.isNotEmpty ? types.first : 'place',
          ),
        );
        if (out.length >= limit) break;
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  Future<List<NearbyPlace>> _googleTextSearch({
    required String query,
    required double nearLat,
    required double nearLng,
    required int limit,
  }) async {
    try {
      final res = await _dio.get(
        'https://maps.googleapis.com/maps/api/place/textsearch/json',
        queryParameters: {
          'query': query,
          'location': '$nearLat,$nearLng',
          'radius': 25000,
          'key': MapsConfig.apiKey,
          'language': 'uz',
        },
      );
      final results = res.data is Map ? res.data['results'] : null;
      if (results is! List) return const [];
      final out = <NearbyPlace>[];
      for (final raw in results) {
        if (raw is! Map) continue;
        final name = raw['name']?.toString().trim();
        if (name == null || name.isEmpty) continue;
        final geo = raw['geometry'];
        final loc = geo is Map ? geo['location'] : null;
        if (loc is! Map) continue;
        final lat = (loc['lat'] as num?)?.toDouble();
        final lng = (loc['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        final types = (raw['types'] as List?)?.map((e) => '$e').toList() ?? [];
        out.add(
          NearbyPlace(
            name: name,
            address: raw['formatted_address']?.toString() ??
                raw['vicinity']?.toString(),
            latitude: lat,
            longitude: lng,
            kind: types.isNotEmpty ? types.first : 'place',
          ),
        );
        if (out.length >= limit) break;
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  Future<String?> _nominatimReverse(double latitude, double longitude) async {
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
      final parts =
          display.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
      return parts.take(2).join(', ');
    } catch (_) {
      return null;
    }
  }

  Future<List<NearbyPlace>> _overpassNearby({
    required double latitude,
    required double longitude,
    required int radiusMeters,
    required int limit,
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
        ]
            .whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .join(' ');
        final city =
            (tags['addr:city'] ?? tags['addr:town'] ?? tags['addr:suburb'])
                ?.toString()
                .trim();
        final address = [
          if (street.isNotEmpty) street,
          if (city != null && city.isNotEmpty) city,
        ].join(', ');

        final kind =
            (tags['amenity'] ?? tags['shop'] ?? tags['tourism'] ?? tags['leisure'])
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

  Future<List<NearbyPlace>> _nominatimSearch({
    required String query,
    required double nearLat,
    required double nearLng,
    required int limit,
  }) async {
    const delta = 0.08;
    try {
      final res = await _dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': query,
          'format': 'jsonv2',
          'limit': limit,
          'addressdetails': 1,
          'viewbox':
              '${nearLng - delta},${nearLat + delta},${nearLng + delta},${nearLat - delta}',
          'bounded': 0,
        },
      );
      final list = res.data;
      if (list is! List) return const [];
      return list.whereType<Map>().map((e) {
        final name =
            e['display_name']?.toString() ?? e['name']?.toString() ?? '';
        final short = name.split(',').first.trim();
        return NearbyPlace(
          name: short.isNotEmpty ? short : name,
          address: name,
          latitude: double.tryParse('${e['lat']}') ?? nearLat,
          longitude: double.tryParse('${e['lon']}') ?? nearLng,
          kind: e['type']?.toString() ?? 'place',
        );
      }).toList();
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
