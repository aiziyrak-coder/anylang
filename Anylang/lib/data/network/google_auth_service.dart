import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../presentation/utils/app_snackbar.dart';

/// Google Sign-In → backend `id_token`.
///
/// Production: set `--dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>`
/// Local: agar client ID yo'q / Play Services ishlamasa — debug dialog orqali
/// backend qabul qiladigan unsigned JWT yaratiladi (GOOGLE_CLIENT_IDS bo'sh bo'lganda).
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
    try {
      final account = await _client.signIn();
      if (account == null) {
        // User cancelled
        return null;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken != null && idToken.isNotEmpty) {
        return idToken;
      }

      // Android ba'zan idToken bermaydi — local debug fallback
      if (kDebugMode) {
        final email = account.email;
        final name = account.displayName ?? email.split('@').first;
        return _mintDevIdToken(email: email, name: name, sub: account.id);
      }

      throw StateError(
        'Google id_token olinmadi. GOOGLE_SERVER_CLIENT_ID ni sozlang',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Google Sign-In failed: $e — trying local fallback');
        final fallback = await _promptDevGoogle();
        if (fallback != null) return fallback;
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _client.signOut();
    } catch (_) {}
  }

  Future<String?> _promptDevGoogle() async {
    final emailCtrl = TextEditingController(text: 'google.user@gmail.com');
    final nameCtrl = TextEditingController(text: 'Google User');
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Local Google (debug)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Google Play / Client ID sozlanmagan. Test uchun email kiriting — '
              'backend local rejimida qabul qiladi.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Ism'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Bekor'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Davom etish'),
          ),
        ],
      ),
      barrierDismissible: false,
    );
    if (ok != true) return null;
    final email = emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      showAppError('Email noto\'g\'ri');
      return null;
    }
    return _mintDevIdToken(
      email: email,
      name: nameCtrl.text.trim().isEmpty ? email.split('@').first : nameCtrl.text.trim(),
      sub: 'local-${email.hashCode.abs()}',
    );
  }

  /// Unsigned JWT — faqat local backend (GOOGLE_CLIENT_IDS bo'sh) uchun.
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
