import '../core/buildNetwork/base_result.dart';
import '../core/buildNetwork/network_client.dart';

class CountriesRepository {
  final NetworkClient _client;

  CountriesRepository({required this._client});

  Future<BaseResult> listCountries() {
    return _client.get(api: 'api/v1/countries');
  }
}
