import '../core/buildNetwork/base_result.dart';
import '../core/buildNetwork/network_client.dart';

class FeedRepository {
  final NetworkClient _client;

  FeedRepository({required NetworkClient client}) : _client = client;

  Future<BaseResult> list({
    int page = 1,
    int limit = 20,
    String? postType,
    int? authorId,
  }) {
    return _client.get(
      api: 'api/v1/feed',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (postType != null && postType.isNotEmpty) 'post_type': postType,
        if (authorId != null) 'author_id': authorId,
      },
    );
  }

  Future<BaseResult> create(Map<String, dynamic> body) {
    return _client.post(api: 'api/v1/feed', data: body);
  }

  Future<BaseResult> delete(int postId) {
    return _client.delete(api: 'api/v1/feed/$postId');
  }
}
