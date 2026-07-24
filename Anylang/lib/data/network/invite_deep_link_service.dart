import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/mappers.dart';
import '../local/session_store.dart';
import 'chat_repository.dart';
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
    final m = inviteTokenInText.firstMatch(text.trim());
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
    await joinAndOpen(token);
  }

  Future<bool> joinAndOpen(String token) async {
    if ((SessionStore.accessToken ?? '').isEmpty) return false;
    if (!Get.isRegistered<ChatRepository>()) return false;
    final result = await Get.find<ChatRepository>().joinByToken(token);
    var ok = false;
    result.when(
      success: (data) {
        ok = true;
        final map = asMap(data) ?? {};
        final chatId = (map['id'] as num?)?.toInt() ?? 0;
        if (chatId <= 0) return;
        final title = map['title']?.toString() ?? 'Guruh';
        final ctx = Get.key.currentContext;
        if (ctx == null) return;
        Navigator.of(ctx).push(
          MaterialPageRoute(
            builder: (_) => (ChatScreen()
                  ..payload = ChatPayload(
                    chatId: chatId,
                    peerId: 0,
                    name: title,
                    initial: title.isNotEmpty ? title[0].toUpperCase() : 'G',
                    avatarGradient: avatarGradientFor(chatId),
                    avatarUrl: map['avatar_url']?.toString(),
                    isGroup: true,
                    myRole: map['my_role']?.toString(),
                    isSuper: map['is_super'] == true,
                    inviteLink: map['invite_link']?.toString(),
                  ))
                .build(),
          ),
        );
      },
      failure: showAppError,
    );
    return ok;
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}
