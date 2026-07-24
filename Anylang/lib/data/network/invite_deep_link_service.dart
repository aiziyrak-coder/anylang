import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/mappers.dart';
import '../local/session_store.dart';
import 'chat_repository.dart';
import '../../presentation/modal/group_invite_bottom_sheet.dart';
import '../../presentation/screens/chat/chat_payload.dart';
import '../../presentation/screens/chat/chat_screen.dart';
import '../../presentation/utils/app_snackbar.dart';

/// `https://anylang.uz/g/{token}` va `anylang://g/{token}` invite deep link.
class InviteDeepLinkService extends GetxService {
  StreamSubscription<Uri>? _sub;
  final _links = AppLinks();

  static final RegExp inviteTokenInText = RegExp(
    r'(?:https?://(?:www\.)?anylang\.uz/g/|anylang://g/)([A-Za-z0-9_-]+)',
    caseSensitive: false,
  );

  static String? tokenFromText(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final m = inviteTokenInText.firstMatch(text);
    return m?.group(1);
  }

  static String? tokenFromUri(Uri uri) {
    if (uri.host == 'anylang.uz' &&
        uri.pathSegments.length >= 2 &&
        uri.pathSegments.first == 'g') {
      return uri.pathSegments[1];
    }
    if (uri.scheme == 'anylang' && uri.host == 'g') {
      return uri.pathSegments.isNotEmpty
          ? uri.pathSegments.first
          : uri.path.replaceFirst('/', '');
    }
    return null;
  }

  Future<InviteDeepLinkService> init() async {
    try {
      final initial = await _links.getInitialLink();
      if (initial != null) {
        unawaited(_handle(initial));
      }
    } catch (_) {}
    _sub = _links.uriLinkStream.listen(_handle);
    return this;
  }

  Future<void> _handle(Uri uri) async {
    final token = tokenFromUri(uri);
    if (token == null || token.isEmpty) return;
    await openInvite(token);
  }

  /// Telegram uslubi: preview sheet (Join pastida) yoki a'zo bo'lsa chat.
  Future<void> openInvite(String token, {BuildContext? context}) async {
    if ((SessionStore.accessToken ?? '').isEmpty) return;
    final ctx = context ?? Get.key.currentContext;
    if (ctx == null) {
      await joinAndOpen(token);
      return;
    }
    await showGroupInviteBottomSheet(ctx, token: token);
  }

  Future<bool> joinAndOpen(
    String token, {
    int? alreadyMemberChatId,
    String? titleHint,
    String? avatarHint,
    bool? isSuperHint,
  }) async {
    if ((SessionStore.accessToken ?? '').isEmpty) return false;
    if (!Get.isRegistered<ChatRepository>()) return false;

    if (alreadyMemberChatId != null && alreadyMemberChatId > 0) {
      _pushChat(
        chatId: alreadyMemberChatId,
        title: titleHint ?? 'Guruh',
        avatarUrl: avatarHint,
        isSuper: isSuperHint ?? false,
      );
      return true;
    }

    final result = await Get.find<ChatRepository>().joinByToken(token);
    var ok = false;
    result.when(
      success: (data) {
        ok = true;
        final map = asMap(data) ?? {};
        final chatId = (map['id'] as num?)?.toInt() ?? 0;
        if (chatId <= 0) return;
        _pushChat(
          chatId: chatId,
          title: map['title']?.toString() ?? titleHint ?? 'Guruh',
          avatarUrl: map['avatar_url']?.toString() ?? avatarHint,
          isSuper: map['is_super'] == true || (isSuperHint ?? false),
          myRole: map['my_role']?.toString(),
          inviteLink: map['invite_link']?.toString(),
        );
      },
      failure: showAppError,
    );
    return ok;
  }

  void _pushChat({
    required int chatId,
    required String title,
    String? avatarUrl,
    bool isSuper = false,
    String? myRole,
    String? inviteLink,
  }) {
    final ctx = Get.key.currentContext;
    if (ctx == null) return;
    final name = title.trim().isEmpty ? 'Guruh' : title.trim();
    Navigator.of(ctx).push(
      MaterialPageRoute(
        builder: (_) => (ChatScreen()
              ..payload = ChatPayload(
                chatId: chatId,
                peerId: 0,
                name: name,
                initial: name.isNotEmpty ? name[0].toUpperCase() : 'G',
                avatarGradient: avatarGradientFor(chatId),
                avatarUrl: avatarUrl,
                isGroup: true,
                myRole: myRole,
                isSuper: isSuper,
                inviteLink: inviteLink,
              ))
            .build(),
      ),
    );
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}
