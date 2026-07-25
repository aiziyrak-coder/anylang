import '../core/buildNetwork/base_result.dart';
import '../core/buildNetwork/network_client.dart';

class NearbyRepository {
  final NetworkClient _client;

  NearbyRepository({required NetworkClient client}) : _client = client;

  Future<BaseResult> updateLocation({
    required double latitude,
    required double longitude,
    bool? sharingEnabled,
  }) {
    return _client.put(
      api: 'api/v1/users/me/location',
      data: {
        'latitude': latitude,
        'longitude': longitude,
        if (sharingEnabled != null) 'sharing_enabled': sharingEnabled,
      },
      notify: SnackNotify.none,
    );
  }

  Future<BaseResult> setSharing({required bool enabled}) {
    return _client.patch(
      api: 'api/v1/users/me/location-sharing',
      data: {'enabled': enabled},
      notify: SnackNotify.errors,
    );
  }

  Future<BaseResult> listNearby({
    required double lat,
    required double lng,
    int radiusM = 2000,
    String? language,
    int limit = 40,
  }) {
    return _client.get(
      api: 'api/v1/users/nearby',
      queryParameters: {
        'lat': lat,
        'lng': lng,
        'radius_m': radiusM,
        'limit': limit,
        if (language != null && language.isNotEmpty) 'language': language,
      },
    );
  }
}
