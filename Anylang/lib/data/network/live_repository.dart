import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import '../core/buildNetwork/base_result.dart';
import '../core/buildNetwork/network_client.dart';

class LiveRepository {
  final NetworkClient _client;

  LiveRepository({required NetworkClient client}) : _client = client;

  Future<BaseResult> languages() {
    return _client.get(api: 'api/v1/live/languages');
  }

  Future<BaseResult> startSession({
    required String myLanguage,
    required String otherLanguage,
  }) {
    return _client.post(
      api: 'api/v1/live/sessions',
      data: {
        'my_language': myLanguage,
        'other_language': otherLanguage,
      },
    );
  }

  Future<BaseResult> endSession(int sessionId) {
    return _client.post(api: 'api/v1/live/sessions/$sessionId/end');
  }

  Future<BaseResult> createTurn({
    required int sessionId,
    required String filePath,
    required String speaker,
    required String clientTurnId,
  }) async {
    final name = filePath.split(RegExp(r'[\\/]')).last;
    final filename = name.toLowerCase().endsWith('.m4a') ? name : '$name.m4a';
    final form = FormData.fromMap({
      'speaker': speaker,
      'client_turn_id': clientTurnId,
      'audio': await MultipartFile.fromFile(
        filePath,
        filename: filename,
        contentType: MediaType('audio', 'mp4'),
      ),
    });
    return _client.post(
      api: 'api/v1/live/sessions/$sessionId/turns',
      data: form,
      notify: SnackNotify.none,
    );
  }

  Future<BaseResult> turns(int sessionId) {
    return _client.get(api: 'api/v1/live/sessions/$sessionId/turns');
  }
}
