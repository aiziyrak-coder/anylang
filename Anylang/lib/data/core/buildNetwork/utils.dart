import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide Response;

import 'base_result.dart';
import 'error.dart';
import 'success.dart';

/// DioException / umumiy xatolardan foydalanuvchiga tushunarli matn (i18n).
String mapDioError(DioException e) {
  if (kDebugMode) {
    debugPrint('API error [${e.response?.statusCode}] ${e.requestOptions.path}');
  }

  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'error_timeout'.tr;
    case DioExceptionType.connectionError:
      final detail = e.message ?? e.error?.toString() ?? '';
      if (detail.toLowerCase().contains('certificate') ||
          detail.toLowerCase().contains('handshake')) {
        return 'error_ssl'.tr;
      }
      return 'error_connection'.tr;
    case DioExceptionType.cancel:
      return 'error_cancelled'.tr;
    case DioExceptionType.badResponse:
      final parsed = _messageFromBody(e.response?.data);
      if (parsed != null && parsed.isNotEmpty) return parsed;
      final code = e.response?.statusCode;
      if (code == 401) return 'error_session_expired'.tr;
      if (code == 403) return 'error_forbidden'.tr;
      if (code == 404) return 'error_not_found'.tr;
      if (code == 429) return 'error_rate_limited'.tr;
      if (code != null && code >= 500) return 'error_server'.tr;
      return 'error_generic'.tr;
    default:
      return 'unknown_error'.tr;
  }
}

String? _messageFromBody(dynamic data) {
  if (data is Map) {
    final message = data['message'];
    if (message is String && message.trim().isNotEmpty) return message.trim();

    final detail = data['detail'];
    if (detail is String && detail.trim().isNotEmpty) return detail.trim();
    if (detail is List && detail.isNotEmpty) {
      final first = detail.first;
      if (first is Map && first['msg'] != null) return first['msg'].toString();
      return first.toString();
    }
  }
  if (data is String && data.trim().isNotEmpty) return data.trim();
  return null;
}

/// Muvaffaqiyatli mutatsiya javobidan foydalanuvchi matni.
String? successMessageFromBody(dynamic data) => _messageFromBody(data);

String? dioErrorCode(DioException e) {
  final data = e.response?.data;
  if (data is Map && data['error_code'] is String) {
    return data['error_code'] as String;
  }
  return null;
}

Map<String, dynamic>? dioErrorBody(DioException e) {
  final data = e.response?.data;
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  return null;
}

Error<String> dioToError(DioException e) {
  final msg = mapDioError(e);
  // error_code foydalanuvchi matniga qo‘shilmaydi — AuthValidators.apiErrorCode
  // body orqali o‘qilishi mumkin; display string toza qoladi.
  final code = dioErrorCode(e);
  if (code != null && code.isNotEmpty) {
    // Kodni saqlash: ko‘p joylar `[CODE]` parse qiladi.
    return Error('$msg [$code]');
  }
  return Error(msg);
}

BaseResult successOrCatch(Response response) {
  return Success(response.data);
}
