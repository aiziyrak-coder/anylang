import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

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

  Future<MultipartFile> _imagePart(String filePath) async {
    final name = filePath.split(RegExp(r'[\\/]')).last;
    final mime = lookupMimeType(filePath, headerBytes: null) ??
        lookupMimeType(name) ??
        'image/jpeg';
    final parts = mime.split('/');
    final filename = name.contains('.') ? name : '$name.jpg';
    return MultipartFile.fromFile(
      filePath,
      filename: filename,
      contentType: MediaType(
        parts.isNotEmpty ? parts[0] : 'image',
        parts.length > 1 ? parts[1] : 'jpeg',
      ),
    );
  }

  Future<BaseResult> uploadAvatar(String filePath) async {
    final formData = FormData.fromMap({
      'file': await _imagePart(filePath),
    });
    return _client.post(api: 'api/v1/users/me/avatar', data: formData);
  }

  Future<BaseResult> uploadBusinessLogo(String filePath) async {
    final formData = FormData.fromMap({
      'file': await _imagePart(filePath),
    });
    return _client.post(api: 'api/v1/users/me/business/logo', data: formData);
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

  Future<BaseResult> uploadFactoryImage(String filePath) async {
    final formData = FormData.fromMap({
      'file': await _imagePart(filePath),
    });
    return _client.post(
      api: 'api/v1/users/me/business/factory-images',
      data: formData,
    );
  }

  Future<BaseResult> blockUser(int peerId) {
    return _client.post(api: 'api/v1/users/me/blocked/$peerId');
  }

  Future<BaseResult> unblockUser(int peerId) {
    return _client.delete(api: 'api/v1/users/me/blocked/$peerId');
  }

  Future<BaseResult> listBlocked() {
    return _client.get(api: 'api/v1/users/me/blocked');
  }
}
