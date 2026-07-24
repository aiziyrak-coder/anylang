import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import '../core/buildNetwork/base_result.dart';
import '../core/buildNetwork/network_client.dart';
import '../core/mappers.dart';

class ChatRepository {
  final NetworkClient _client;

  ChatRepository({required NetworkClient client}) : _client = client;

  Future<BaseResult> listChats({
    int page = 1,
    int limit = 50,
    String sort = 'activity',
    String? type,
  }) {
    return _client.get(
      api: 'api/v1/chats',
      queryParameters: {
        'page': page,
        'limit': limit,
        'sort': sort,
        if (type != null && type.isNotEmpty) 'type': type,
      },
    );
  }

  Future<BaseResult> createChat(int userId) {
    return _client.post(
      api: 'api/v1/chats',
      data: {'user_id': userId},
      notify: SnackNotify.none,
    );
  }

  Future<BaseResult> createGroup({
    required String title,
    required List<int> userIds,
  }) {
    return _client.post(
      api: 'api/v1/chats/groups',
      data: {
        'title': title,
        'user_ids': userIds,
      },
      notify: SnackNotify.none,
    );
  }

  Future<BaseResult> pinChat(int chatId) {
    return _client.post(api: 'api/v1/chats/$chatId/pin', notify: SnackNotify.none);
  }

  Future<BaseResult> unpinChat(int chatId) {
    return _client.delete(api: 'api/v1/chats/$chatId/pin', notify: SnackNotify.none);
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

  Future<BaseResult> updateGroup({
    required int chatId,
    String? title,
  }) {
    return _client.patch(
      api: 'api/v1/chats/$chatId',
      data: {
        if (title != null) 'title': title,
      },
      notify: SnackNotify.none,
    );
  }

  Future<BaseResult> clearHistory(int chatId, {bool forEveryone = false}) {
    return _client.post(
      api: 'api/v1/chats/$chatId/clear',
      data: {'for_everyone': forEveryone},
      notify: SnackNotify.none,
    );
  }

  Future<BaseResult> editMessage(int messageId, {required String text}) {
    return _client.patch(
      api: 'api/v1/messages/$messageId',
      data: {'text': text},
      notify: SnackNotify.none,
    );
  }

  Future<BaseResult> forwardMessage(
    int messageId, {
    required List<int> chatIds,
    bool hideSender = false,
  }) {
    return _client.post(
      api: 'api/v1/messages/$messageId/forward',
      data: {
        'chat_ids': chatIds,
        'hide_sender': hideSender,
      },
      notify: SnackNotify.none,
    );
  }

  Future<BaseResult> pinMessage(int chatId, int messageId) {
    return _client.post(
      api: 'api/v1/chats/$chatId/messages/$messageId/pin',
      notify: SnackNotify.none,
    );
  }

  Future<BaseResult> unpinMessage(int chatId, int messageId) {
    return _client.delete(
      api: 'api/v1/chats/$chatId/messages/$messageId/pin',
      notify: SnackNotify.none,
    );
  }

  Future<BaseResult> listPinnedMessages(int chatId) {
    return _client.get(api: 'api/v1/chats/$chatId/pinned-messages');
  }

  Future<BaseResult> setReaction(int messageId, {required String emoji}) {
    return _client.post(
      api: 'api/v1/messages/$messageId/reactions',
      data: {'emoji': emoji},
      notify: SnackNotify.none,
    );
  }

  Future<BaseResult> removeReaction(int messageId) {
    return _client.delete(
      api: 'api/v1/messages/$messageId/reactions',
      notify: SnackNotify.none,
    );
  }

  Future<BaseResult> listReactions(int messageId) {
    return _client.get(api: 'api/v1/messages/$messageId/reactions');
  }

  Future<BaseResult> listMembers(int chatId) {
    return _client.get(api: 'api/v1/chats/$chatId/members');
  }

  Future<BaseResult> addMembers(int chatId, {required List<int> userIds}) {
    return _client.post(
      api: 'api/v1/chats/$chatId/members',
      data: {'user_ids': userIds},
      notify: SnackNotify.none,
    );
  }

  Future<BaseResult> removeMember(int chatId, int userId) {
    return _client.delete(
      api: 'api/v1/chats/$chatId/members/$userId',
      notify: SnackNotify.none,
    );
  }

  Future<BaseResult> leaveGroup(int chatId) {
    return _client.post(
      api: 'api/v1/chats/$chatId/leave',
      notify: SnackNotify.none,
    );
  }

  Future<BaseResult> transferOwnership(int chatId, {required int userId}) {
    return _client.post(
      api: 'api/v1/chats/$chatId/transfer-ownership',
      data: {'user_id': userId},
      notify: SnackNotify.none,
    );
  }

  Future<BaseResult> deleteGroup(int chatId) {
    return _client.delete(
      api: 'api/v1/chats/$chatId',
      notify: SnackNotify.none,
    );
  }

  Future<BaseResult> promoteAdmin(int chatId, int userId) {
    return _client.post(
      api: 'api/v1/chats/$chatId/admins/$userId',
      notify: SnackNotify.none,
    );
  }

  Future<BaseResult> demoteAdmin(int chatId, int userId) {
    return _client.delete(
      api: 'api/v1/chats/$chatId/admins/$userId',
      notify: SnackNotify.none,
    );
  }

  Future<BaseResult> getInvite(int chatId) {
    return _client.get(api: 'api/v1/chats/$chatId/invite');
  }

  Future<BaseResult> regenerateInvite(int chatId) {
    return _client.post(
      api: 'api/v1/chats/$chatId/invite',
      notify: SnackNotify.none,
    );
  }

  Future<BaseResult> disableInvite(int chatId) {
    return _client.delete(
      api: 'api/v1/chats/$chatId/invite',
      notify: SnackNotify.none,
    );
  }

  Future<BaseResult> joinByToken(String token) {
    return _client.post(
      api: 'api/v1/chats/join/$token',
      notify: SnackNotify.none,
    );
  }

  Future<BaseResult> previewInvite(String token) {
    return _client.get(api: 'api/v1/chats/invite/$token');
  }

  Future<BaseResult> uploadGroupAvatar(int chatId, String filePath) async {
    final name = filePath.split(RegExp(r'[\\/]')).last;
    final mime = lookupMimeType(filePath) ?? 'image/jpeg';
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        filePath,
        filename: name,
        contentType: MediaType.parse(mime),
      ),
    });
    return _client.post(
      api: 'api/v1/chats/$chatId/avatar',
      data: form,
      notify: SnackNotify.none,
    );
  }

  Future<BaseResult> hideChat(int chatId) {
    return _client.post(api: 'api/v1/chats/$chatId/hide', notify: SnackNotify.none);
  }

  Future<BaseResult> muteChat(int chatId) {
    return _client.post(api: 'api/v1/chats/$chatId/mute', notify: SnackNotify.none);
  }

  Future<BaseResult> unmuteChat(int chatId) {
    return _client.delete(api: 'api/v1/chats/$chatId/mute', notify: SnackNotify.none);
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
