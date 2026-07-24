import '../core/buildNetwork/base_result.dart';
import '../core/buildNetwork/network_client.dart';

class LanguagesRepository {
  final NetworkClient _client;

  LanguagesRepository({required NetworkClient client}) : _client = client;

  Future<BaseResult> listLanguages() {
    return _client.get(api: 'api/v1/languages');
  }
}
