import '../core/buildNetwork/base_result.dart';
import '../core/buildNetwork/network_client.dart';

class FriendsRepository {
  final NetworkClient _client;

  FriendsRepository({required NetworkClient client}) : _client = client;

  Future<BaseResult> listFriends({int page = 1, int limit = 50}) {
    return _client.get(
      api: 'api/v1/friends',
      queryParameters: {'page': page, 'limit': limit},
    );
  }

  Future<BaseResult> listRequests({
    String type = 'incoming',
    bool includeDeclined = false,
    int page = 1,
    int limit = 50,
  }) {
    return _client.get(
      api: 'api/v1/friends/requests',
      queryParameters: {
        'type': type,
        'page': page,
        'limit': limit,
        if (includeDeclined) 'include_declined': true,
      },
    );
  }

  Future<BaseResult> sendRequest(int userId) {
    return _client.post(
      api: 'api/v1/friends/requests',
      data: {'user_id': userId},
    );
  }

  Future<BaseResult> acceptRequest(int requestId) {
    return _client.post(api: 'api/v1/friends/requests/$requestId/accept');
  }

  Future<BaseResult> declineRequest(int requestId) {
    return _client.post(api: 'api/v1/friends/requests/$requestId/decline');
  }

  Future<BaseResult> removeFriend(int userId) {
    return _client.delete(api: 'api/v1/friends/$userId');
  }
}
