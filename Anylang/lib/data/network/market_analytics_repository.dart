import '../core/buildNetwork/base_result.dart';
import '../core/buildNetwork/network_client.dart';

class MarketAnalyticsRepository {
  final NetworkClient _client;

  MarketAnalyticsRepository({required NetworkClient client}) : _client = client;

  Future<BaseResult> insights({String locale = 'uz'}) {
    return _client.get(
      api: 'api/v1/market-analytics/insights',
      queryParameters: {'locale': locale},
    );
  }
}
