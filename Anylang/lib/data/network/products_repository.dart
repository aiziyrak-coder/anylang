import '../core/buildNetwork/base_result.dart';
import '../core/buildNetwork/network_client.dart';

class ProductsRepository {
  final NetworkClient _client;

  ProductsRepository({required NetworkClient client}) : _client = client;

  Future<BaseResult> list({int page = 1, int limit = 40, String? q}) {
    return _client.get(
      api: 'api/v1/products',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (q != null && q.isNotEmpty) 'q': q,
      },
    );
  }

  Future<BaseResult> top({int limit = 10}) {
    return _client.get(
      api: 'api/v1/products/top',
      queryParameters: {'limit': limit},
    );
  }

  Future<BaseResult> detail(int productId) {
    return _client.get(api: 'api/v1/products/$productId');
  }

  Future<BaseResult> categories() {
    return _client.get(api: 'api/v1/products/categories');
  }

  Future<BaseResult> create(Map<String, dynamic> body) {
    return _client.post(api: 'api/v1/products', data: body);
  }
}
