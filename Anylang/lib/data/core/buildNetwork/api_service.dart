import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide FormData, MultipartFile, Response;

import 'api_config.dart';
import 'token_refresher.dart';

class ApiService {
  late final Dio dio;
  final TokenRefresher tokenRefresher;

  ApiService({TokenRefresher? tokenRefresher})
      : tokenRefresher = tokenRefresher ?? TokenRefresher() {
    dio = Dio(
      BaseOptions(
        baseUrl: kBaseUrl,
        connectTimeout: const Duration(seconds: 12),
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 25),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.data is FormData) {
            options.headers.remove('Content-Type');
          }
          // Skip auth header for public auth endpoints
          final path = options.path;
          final skipAuth = path.contains('auth/login') ||
              path.contains('auth/register') ||
              path.contains('auth/google') ||
              path.contains('auth/refresh') ||
              path.contains('auth/verify-email') ||
              path.contains('auth/resend') ||
              path.contains('auth/password') ||
              path.contains('countries');

          if (!skipAuth) {
            final token = await this.tokenRefresher.getToken();
            if (token.isNotEmpty && token != 'none') {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          final status = error.response?.statusCode;
          final path = error.requestOptions.path;
          final isRefresh = path.contains('auth/refresh');
          final alreadyRetried =
              error.requestOptions.extra['auth_retry'] == true;

          if (status == 401 && !isRefresh && !alreadyRetried) {
            final fresh = await this.tokenRefresher.getNewToken();
            if (fresh.isNotEmpty && fresh != 'none') {
              final req = error.requestOptions;
              req.headers['Authorization'] = 'Bearer $fresh';
              req.extra['auth_retry'] = true;
              try {
                final response = await dio.fetch(req);
                return handler.resolve(response);
              } catch (e) {
                if (e is DioException) {
                  return handler.next(e);
                }
                return handler.next(error);
              }
            }
            // Session gone — UI can react via GetX event
            if (Get.isRegistered<SessionExpiredBus>()) {
              Get.find<SessionExpiredBus>().notify();
            }
          }
          return handler.next(error);
        },
      ),
    );

    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          requestBody: false,
          responseBody: false,
          requestHeader: false,
          responseHeader: false,
          error: true,
          logPrint: (o) => debugPrint('$o'),
        ),
      );
    }
  }

  Future<String?> getToken() => tokenRefresher.getToken();
}

/// Lightweight bus so screens can route to login on session death.
class SessionExpiredBus extends GetxService {
  final tick = 0.obs;

  void notify() {
    tick.value++;
  }
}
