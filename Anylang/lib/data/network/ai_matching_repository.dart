import '../core/buildNetwork/base_result.dart';
import '../core/buildNetwork/network_client.dart';

class AiMatchingRepository {
  final NetworkClient _client;

  AiMatchingRepository({required NetworkClient client}) : _client = client;

  Future<BaseResult> matches({String locale = 'uz'}) {
    return _client.get(
      api: 'api/v1/ai-matching/matches',
      queryParameters: {'locale': locale},
    );
  }

  Future<BaseResult> recommendations({
    String locale = 'uz',
    int limit = 12,
  }) {
    return _client.get(
      api: 'api/v1/ai-matching/recommendations',
      queryParameters: {
        'locale': locale,
        'limit': limit,
      },
    );
  }
}
