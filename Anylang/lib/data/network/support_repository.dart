import '../core/buildNetwork/base_result.dart';
import '../core/buildNetwork/network_client.dart';

class SupportRepository {
  final NetworkClient _client;

  SupportRepository({required NetworkClient client}) : _client = client;

  Future<BaseResult> fetchActiveSession() {
    return _client.get(
      api: 'api/v1/support/sessions/active',
    );
  }

  Future<BaseResult> listSessions({int limit = 50}) {
    return _client.get(
      api: 'api/v1/support/sessions',
      queryParameters: {'limit': limit},
    );
  }

  Future<BaseResult> getSession(int sessionId) {
    return _client.get(
      api: 'api/v1/support/sessions/$sessionId',
    );
  }

  Future<BaseResult> rateSession({
    required int sessionId,
    required int rating,
  }) {
    return _client.post(
      api: 'api/v1/support/sessions/$sessionId/rate',
      data: {'rating': rating},
      notify: SnackNotify.none,
    );
  }

  Future<BaseResult> send({
    required String message,
    required List<Map<String, String>> history,
    required String locale,
    int? sessionId,
  }) {
    return _client.post(
      api: 'api/v1/support/chat',
      data: {
        'message': message,
        'history': history,
        'locale': locale,
        if (sessionId != null && sessionId > 0) 'session_id': sessionId,
      },
      notify: SnackNotify.none,
    );
  }
}
