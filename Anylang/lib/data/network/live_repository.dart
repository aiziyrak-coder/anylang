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
    String ttsVoice = 'female',
    double ttsSpeed = 1.0,
  }) async {
    final name = filePath.split(RegExp(r'[\\/]')).last;
    final filename = name.toLowerCase().endsWith('.m4a') ? name : '$name.m4a';
    final speed = ttsSpeed.clamp(0.5, 2.0);
    final voice = ttsVoice == 'male' ? 'male' : 'female';
    final form = FormData.fromMap({
      'speaker': speaker,
      'client_turn_id': clientTurnId,
      'tts_voice': voice,
      'tts_speed': speed,
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

  /// Kamera/rasm → OCR + tarjima.
  Future<BaseResult> ocrTranslate({
    required String filePath,
    required String targetLanguage,
    String? sourceLanguage,
    int? sessionId,
    String? clientTurnId,
    String ttsVoice = 'female',
    double ttsSpeed = 1.0,
  }) async {
    final name = filePath.split(RegExp(r'[\\/]')).last;
    final lower = name.toLowerCase();
    String filename = name;
    String subtype = 'jpeg';
    if (lower.endsWith('.png')) {
      subtype = 'png';
    } else if (lower.endsWith('.webp')) {
      subtype = 'webp';
    } else if (!lower.endsWith('.jpg') && !lower.endsWith('.jpeg')) {
      filename = '$name.jpg';
    }
    final speed = ttsSpeed.clamp(0.5, 2.0);
    final voice = ttsVoice == 'male' ? 'male' : 'female';
    final form = FormData.fromMap({
      'target_language': targetLanguage,
      if (sourceLanguage != null && sourceLanguage.isNotEmpty)
        'source_language': sourceLanguage,
      if (sessionId != null) 'session_id': sessionId,
      if (clientTurnId != null && clientTurnId.isNotEmpty)
        'client_turn_id': clientTurnId,
      'tts_voice': voice,
      'tts_speed': speed,
      'image': await MultipartFile.fromFile(
        filePath,
        filename: filename,
        contentType: MediaType('image', subtype),
      ),
    });
    return _client.post(
      api: 'api/v1/live/ocr-translate',
      data: form,
      notify: SnackNotify.none,
    );
  }

  /// Bugungi (yoki barcha) sessiyalar tarixi.
  Future<BaseResult> sessions({
    bool today = true,
    String? q,
    int limit = 40,
  }) {
    return _client.get(
      api: 'api/v1/live/sessions',
      queryParameters: {
        'today': today,
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        'limit': limit,
      },
    );
  }

  /// TXT/PDF eksport — xom baytlar.
  Future<List<int>?> exportBytes({
    String format = 'txt',
    bool today = true,
    int? sessionId,
  }) async {
    try {
      final response = await _client.apiService.dio.get<List<int>>(
        'api/v1/live/sessions/export',
        queryParameters: {
          'format': format,
          'today': today,
          if (sessionId != null) 'session_id': sessionId,
        },
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      if (data == null) return null;
      return List<int>.from(data);
    } catch (_) {
      return null;
    }
  }
}
