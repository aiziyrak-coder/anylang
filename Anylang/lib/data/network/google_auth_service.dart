import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../presentation/utils/app_snackbar.dart';

/// Foydalanuvchi Google oynasini yopdi / bekor qildi.
class GoogleSignInCancelled implements Exception {}

/// SHA-1 / Android OAuth / Consent sozlanmagan (ApiException 10 va h.k.).
class GoogleSignInNotConfigured implements Exception {
  final String messageKey;
  GoogleSignInNotConfigured([this.messageKey = 'google_android_oauth_missing']);
}

/// Google Sign-In → backend `id_token`.
///
/// Production: `--dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>`
/// yoki `Anylang/.env` dagi `GOOGLE_SERVER_CLIENT_ID` (release build skripti).
///
/// Debug: client ID yo‘q bo‘lsa — email dialog orqali bootstrap token
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
    // Release: faqat real Google — bootstrap yo‘q.
    if (serverClientId.isEmpty) {
      if (kDebugMode) return _promptBootstrapGoogle();
      throw GoogleSignInNotConfigured('google_coming_soon');
    }

    try {
      await _client.signOut();
    } catch (_) {}

    try {
      final account = await _client.signIn();
      if (account == null) throw GoogleSignInCancelled();

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken != null && idToken.isNotEmpty) return idToken;

      // idToken yo‘q — odatda Android OAuth client / SHA-1 yo‘q.
      if (kDebugMode) {
        final email = account.email;
        final name = account.displayName ?? email.split('@').first;
        return _mintDevIdToken(email: email, name: name, sub: account.id);
      }
      throw GoogleSignInNotConfigured();
    } on GoogleSignInCancelled {
      rethrow;
    } on GoogleSignInNotConfigured {
      rethrow;
    } on PlatformException catch (e) {
      debugPrint('Google Sign-In PlatformException: ${e.code} ${e.message}');
      final blob = '${e.code} ${e.message} ${e.details}'.toLowerCase();
      if (blob.contains('network_error') || blob.contains('7')) {
        rethrow;
      }
      // 10 = DEVELOPER_ERROR (package/SHA-1), 12500 = generic sign-in fail
      if (blob.contains('10') ||
          blob.contains('developer_error') ||
          blob.contains('12500') ||
          blob.contains('sign_in_failed')) {
        throw GoogleSignInNotConfigured();
      }
      rethrow;
    } catch (e) {
      debugPrint('Google Sign-In failed: $e');
      if (kDebugMode) {
        final fallback = await _promptBootstrapGoogle();
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
