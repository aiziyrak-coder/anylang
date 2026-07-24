import '../core/buildNetwork/base_result.dart';
import '../core/buildNetwork/network_client.dart';

class NumbersRepository {
  final NetworkClient _client;

  NumbersRepository({required NetworkClient client}) : _client = client;

  Future<BaseResult> myNumber() {
    return _client.get(api: 'api/v1/numbers/me');
  }

  Future<BaseResult> groups() {
    return _client.get(api: 'api/v1/numbers/groups');
  }

  Future<BaseResult> catalog({
    String? search,
    int? groupId,
    bool? hasBonus,
    String sort = 'price_asc',
    int page = 1,
    int limit = 30,
  }) {
    return _client.get(
      api: 'api/v1/numbers/catalog',
      queryParameters: {
        'page': page,
        'limit': limit,
        'sort': sort,
        if (search != null && search.isNotEmpty) 'search': search,
        if (groupId != null) 'group_id': groupId,
        if (hasBonus != null) 'has_bonus': hasBonus,
      },
    );
  }

  Future<BaseResult> random() {
    return _client.post(api: 'api/v1/numbers/random');
  }

  Future<BaseResult> reserve(String number) {
    return _client.post(
      api: 'api/v1/numbers/reserve',
      data: {'number': number},
    );
  }

  Future<BaseResult> purchaseFree(String number) {
    return _client.post(
      api: 'api/v1/numbers/purchase',
      data: {'number': number},
    );
  }
}
