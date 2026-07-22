import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../presentation/utils/app_snackbar.dart';

/// Google Sign-In → backend `id_token`.
///
/// Production: `--dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>`
/// Agar client ID yo‘q bo‘lsa — email dialog orqali bootstrap token
/// (server `GOOGLE_CLIENT_IDS` bo‘sh bo‘lganda qabul qiladi).
class GoogleAuthService {
  static const String serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  GoogleSignIn get _client => GoogleSignIn(
        scopes: const ['email', 'profile', 'openid'],
        serverClientId: serverClientId.isEmpty ? null : serverClientId,
      );

  Future<String?> signInForIdToken() async {
    // Client ID yo‘q — Play Services idToken bermaydi; bootstrap dialog.
    if (serverClientId.isEmpty) {
      return _promptBootstrapGoogle();
    }

    try {
      final account = await _client.signIn();
      if (account == null) return null;
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken != null && idToken.isNotEmpty) return idToken;

      // idToken yo‘q — bootstrap fallback
      final email = account.email;
      final name = account.displayName ?? email.split('@').first;
      return _mintDevIdToken(email: email, name: name, sub: account.id);
    } catch (e) {
      debugPrint('Google Sign-In failed: $e');
      final fallback = await _promptBootstrapGoogle();
      if (fallback != null) return fallback;
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _client.signOut();
    } catch (_) {}
  }

  Future<String?> _promptBootstrapGoogle() async {
    final emailCtrl = TextEditingController(text: '');
    final nameCtrl = TextEditingController(text: '');
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: Text('google_bootstrap_title'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('google_bootstrap_hint'.tr),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              decoration: InputDecoration(labelText: 'email'.tr),
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
            ),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(labelText: 'full_name'.tr),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('settings_cancel'.tr),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text('continue'.tr),
          ),
        ],
      ),
      barrierDismissible: false,
    );
    if (ok != true) return null;
    final email = emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      showAppError('email_invalid'.tr);
      return null;
    }
    final name = nameCtrl.text.trim().isEmpty
        ? email.split('@').first
        : nameCtrl.text.trim();
    return _mintDevIdToken(
      email: email,
      name: name,
      sub: 'bootstrap-${email.hashCode.abs()}',
    );
  }

  /// Unsigned JWT — server GOOGLE_CLIENT_IDS bo‘sh bo‘lganda.
  String _mintDevIdToken({
    required String email,
    required String name,
    required String sub,
  }) {
    String b64(Map<String, dynamic> m) {
      final raw = utf8.encode(jsonEncode(m));
      return base64Url.encode(raw).replaceAll('=', '');
    }

    final header = b64({'alg': 'none', 'typ': 'JWT'});
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final payload = b64({
      'iss': 'https://accounts.google.com',
      'aud': 'anylang-local',
      'sub': sub,
      'email': email,
      'email_verified': true,
      'name': name,
      'picture': null,
      'iat': now,
      'exp': now + 3600,
    });
    return '$header.$payload.dev';
  }
}
