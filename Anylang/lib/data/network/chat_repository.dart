import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import '../core/buildNetwork/base_result.dart';
import '../core/buildNetwork/network_client.dart';
import '../core/mappers.dart';

class ChatRepository {
  final NetworkClient _client;

  ChatRepository({required NetworkClient client}) : _client = client;

  Future<BaseResult> listChats({int page = 1, int limit = 50}) {
    return _client.get(
      api: 'api/v1/chats',
      queryParameters: {'page': page, 'limit': limit},
    );
  }

  Future<BaseResult> createChat(int userId) {
    return _client.post(
      api: 'api/v1/chats',
      data: {'user_id': userId},
      notify: SnackNotify.none,
    );
  }

  Future<BaseResult> listMessages(int chatId, {int? beforeId, int limit = 50}) {
    return _client.get(
      api: 'api/v1/chats/$chatId/messages',
      queryParameters: {
        'limit': limit,
        if (beforeId != null) 'before_id': beforeId,
      },
    );
  }

  Future<BaseResult> sendText({
    required int chatId,
    required String text,
    required String clientMessageId,
    int? replyToId,
  }) {
    return _client.post(
      api: 'api/v1/chats/$chatId/messages',
      data: {
        'client_message_id': clientMessageId,
        'type': 'text',
        'text': text,
        if (replyToId != null) 'reply_to_id': replyToId,
      },
      notify: SnackNotify.none,
    );
  }

  Future<BaseResult> markRead(int chatId, List<int> messageIds) {
    return _client.post(
      api: 'api/v1/chats/$chatId/read',
      data: {'message_ids': messageIds},
      notify: SnackNotify.none,
    );
  }

  Future<BaseResult> search(String q) {
    return _client.get(
      api: 'api/v1/chats/search',
      queryParameters: {'query': q},
    );
  }

  Future<BaseResult> uploadMedia({
    required String filePath,
    required String mediaType,
  }) async {
    final form = FormData.fromMap({
      'media_type': mediaType,
      'file': await MultipartFile.fromFile(
        filePath,
        filename: filePath.split(RegExp(r'[\\/]')).last,
        contentType: MediaType('audio', 'mp4'),
      ),
    });
    return _client.post(api: 'api/v1/chats/media', data: form, notify: SnackNotify.none);
  }

  Future<BaseResult> sendVoice({
    required int chatId,
    required String clientMessageId,
    required int mediaId,
    Map<String, dynamic>? meta,
    int? replyToId,
  }) {
    return _client.post(
      api: 'api/v1/chats/$chatId/messages',
      data: {
        'client_message_id': clientMessageId,
        'type': 'voice',
        'media_id': mediaId,
        if (meta != null) 'meta': meta,
        if (replyToId != null) 'reply_to_id': replyToId,
      },
      notify: SnackNotify.none,
    );
  }

  /// Xabarni men uchun yashirish (`for_everyone=false`).
  Future<BaseResult> deleteMessage(int messageId, {bool forEveryone = false}) {
    return _client.delete(
      api: 'api/v1/messages/$messageId',
      queryParameters: {'for_everyone': forEveryone},
      notify: SnackNotify.none,
    );
  }
}

extension ChatResultX on BaseResult {
  List<Map<String, dynamic>> chatItems() =>
      asList(dataOrNull).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}
