import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../local/session_store.dart';
import 'api_config.dart';

/// Single-flight token refresh with JWT exp awareness.
class TokenRefresher {
  TokenRefresher();

  Completer<String>? _refreshCompleter;

  Future<String> getToken() async {
    final current = SessionStore.accessToken;
    if (current == null || current.isEmpty || current == 'none') {
      return 'none';
    }
    if (await tokenExpired()) {
      return getNewToken();
    }
    return current;
  }

  Future<bool> tokenExpired() async {
    final access = SessionStore.accessToken;
    final fromJwt = _jwtExpMillis(access);
    final expireMillis = fromJwt ??
        SessionStore.tokenExpireTime ??
        DateTime.now().millisecondsSinceEpoch;
    final expireTime = DateTime.fromMillisecondsSinceEpoch(expireMillis);
    return expireTime.isBefore(DateTime.now().add(const Duration(minutes: 1)));
  }

  Future<String> getNewToken() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final completer = Completer<String>();
    _refreshCompleter = completer;

    try {
      final refreshTokenValue = SessionStore.refreshToken;
      if (refreshTokenValue == null ||
          refreshTokenValue.isEmpty ||
          refreshTokenValue == 'none') {
        await SessionStore.clear();
        completer.complete('none');
        return 'none';
      }

      final response = await _refreshApi(refreshTokenValue);
      final accessToken = response['access_token']?.toString();
      final newRefreshToken = response['refresh_token']?.toString();
      if (accessToken == null ||
          accessToken.isEmpty ||
          newRefreshToken == null ||
          newRefreshToken.isEmpty) {
        await SessionStore.clear();
        completer.complete('none');
        return 'none';
      }

      final expiresIn = response['expires_in'];
      await SessionStore.saveTokens(
        accessToken: accessToken,
        refreshToken: newRefreshToken,
        expiresInSeconds: expiresIn is num ? expiresIn.toInt() : null,
      );
      completer.complete(accessToken);
      return accessToken;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Token refresh failed: $e');
      }
      // Faqat aniq auth o‘limida sessiyani o‘chiramiz.
      // 5xx / 429 / timeout — vaqtinchalik; foydalanuvchini login’ga uloqtirilmasin.
      if (e is DioException) {
        final type = e.type;
        final status = e.response?.statusCode ?? 0;
        final isTransient = type == DioExceptionType.connectionError ||
            type == DioExceptionType.connectionTimeout ||
            type == DioExceptionType.receiveTimeout ||
            type == DioExceptionType.sendTimeout ||
            status == 408 ||
            status == 429 ||
            status >= 500;
        if (isTransient) {
          final fallback = SessionStore.accessToken;
          completer.complete(fallback ?? 'none');
          return fallback ?? 'none';
        }
        // 401/403 refresh — token haqiqatan yaroqsiz.
        if (status == 401 || status == 403) {
          await SessionStore.clear();
          completer.complete('none');
          return 'none';
        }
      }
      // Noma’lum xato: sessiya saqlansin (offline / parse glitch).
      final fallback = SessionStore.accessToken;
      completer.complete(fallback ?? 'none');
      return fallback ?? 'none';
    } finally {
      _refreshCompleter = null;
    }
  }

  Future<Map<String, dynamic>> _refreshApi(String refreshToken) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    final response = await dio.post(
      '$kBaseUrl/$kRefreshTokenApi',
      data: {'refresh_token': refreshToken},
      options: Options(
        headers: {
          'accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw StateError('Invalid refresh response');
  }

  static int? _jwtExpMillis(String? token) {
    if (token == null || token.isEmpty) return null;
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final normalized = base64Url.normalize(parts[1]);
      final payload =
          jsonDecode(utf8.decode(base64Url.decode(normalized))) as Map;
      final exp = payload['exp'];
      if (exp is int) return exp * 1000;
      if (exp is num) return exp.toInt() * 1000;
    } catch (_) {}
    return null;
  }
}
