import '../core/buildNetwork/base_result.dart';
import '../core/buildNetwork/network_client.dart';

class MarketplaceGroupsRepository {
  final NetworkClient _client;

  MarketplaceGroupsRepository({required NetworkClient client}) : _client = client;

  Future<BaseResult> list() {
    return _client.get(api: 'api/v1/marketplace-groups');
  }

  Future<BaseResult> preview(String slug) {
    return _client.get(api: 'api/v1/marketplace-groups/$slug/preview');
  }

  Future<BaseResult> join(String slug) {
    return _client.post(api: 'api/v1/marketplace-groups/$slug/join');
  }
}
