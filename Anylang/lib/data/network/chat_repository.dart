import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

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

  Future<BaseResult> sendMessage({
    required int chatId,
    required String clientMessageId,
    required String type,
    String? text,
    Map<String, dynamic>? meta,
    int? mediaId,
    int? replyToId,
  }) {
    return _client.post(
      api: 'api/v1/chats/$chatId/messages',
      data: {
        'client_message_id': clientMessageId,
        'type': type,
        if (text != null) 'text': text,
        if (meta != null) 'meta': meta,
        if (mediaId != null) 'media_id': mediaId,
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
    final filename = filePath.split(RegExp(r'[\\/]')).last;
    final mime = lookupMimeType(filePath) ??
        lookupMimeType(filename) ??
        'application/octet-stream';
    final parts = mime.split('/');
    final contentType = MediaType(
      parts.isNotEmpty ? parts.first : 'application',
      parts.length > 1 ? parts[1] : 'octet-stream',
    );
    final form = FormData.fromMap({
      'media_type': mediaType,
      'file': await MultipartFile.fromFile(
        filePath,
        filename: filename,
        contentType: contentType,
      ),
    });
    return _client.post(
      api: 'api/v1/chats/media',
      data: form,
      notify: SnackNotify.none,
    );
  }

  Future<BaseResult> sendVoice({
    required int chatId,
    required String clientMessageId,
    required int mediaId,
    Map<String, dynamic>? meta,
    int? replyToId,
  }) {
    return sendMessage(
      chatId: chatId,
      clientMessageId: clientMessageId,
      type: 'voice',
      mediaId: mediaId,
      meta: meta,
      replyToId: replyToId,
    );
  }

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
