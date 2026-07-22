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
      final isNetwork = e is DioException &&
          (e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.sendTimeout);
      if (isNetwork) {
        final fallback = SessionStore.accessToken;
        completer.complete(fallback ?? 'none');
        return fallback ?? 'none';
      }
      await SessionStore.clear();
      completer.complete('none');
      return 'none';
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
