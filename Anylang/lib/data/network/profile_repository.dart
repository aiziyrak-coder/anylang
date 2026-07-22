import 'package:dio/dio.dart';

import '../core/buildNetwork/base_result.dart';
import '../core/buildNetwork/network_client.dart';

class ProfileRepository {
  final NetworkClient _client;

  ProfileRepository({required NetworkClient client}) : _client = client;

  Future<BaseResult> getMe() {
    return _client.get(api: 'api/v1/users/me');
  }

  Future<BaseResult> updateMe(Map<String, dynamic> body) {
    return _client.patch(api: 'api/v1/users/me', data: body);
  }

  Future<BaseResult> uploadAvatar(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    return _client.post(api: 'api/v1/users/me/avatar', data: formData);
  }

  Future<BaseResult> getBusiness() {
    return _client.get(api: 'api/v1/users/me/business');
  }

  Future<BaseResult> updateBusiness(Map<String, dynamic> body) {
    return _client.patch(api: 'api/v1/users/me/business', data: body);
  }

  Future<BaseResult> searchUsers(String q) {
    return _client.get(
      api: 'api/v1/users/search',
      queryParameters: {'query': q},
    );
  }

  Future<BaseResult> getPublicUser(int userId) {
    return _client.get(api: 'api/v1/users/$userId');
  }
}
