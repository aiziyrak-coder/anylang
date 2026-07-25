import '../core/buildNetwork/base_result.dart';
import '../core/buildNetwork/network_client.dart';

class TradeAssistantRepository {
  final NetworkClient _client;

  TradeAssistantRepository({required NetworkClient client}) : _client = client;

  Future<BaseResult> send({
    required String message,
    required List<Map<String, String>> history,
    required String locale,
    int? sellerId,
  }) {
    return _client.post(
      api: 'api/v1/trade-assistant/chat',
      data: {
        'message': message,
        'history': history,
        'locale': locale,
        if (sellerId != null) 'seller_id': sellerId,
      },
      notify: SnackNotify.none,
    );
  }
}
