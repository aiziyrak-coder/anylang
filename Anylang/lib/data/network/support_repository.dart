import '../core/buildNetwork/base_result.dart';
import '../core/buildNetwork/network_client.dart';

class SupportRepository {
  final NetworkClient _client;

  SupportRepository({required NetworkClient client}) : _client = client;

  Future<BaseResult> send({
    required String message,
    required List<Map<String, String>> history,
    required String locale,
  }) {
    return _client.post(
      api: 'api/v1/support/chat',
      data: {
        'message': message,
        'history': history,
        'locale': locale,
      },
      notify: SnackNotify.none,
    );
  }
}
