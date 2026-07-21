import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'base_result.dart';
import 'error.dart';
import 'success.dart';

/// DioException / umumiy xatolardan foydalanuvchiga tushunarli matn.
String mapDioError(DioException e) {
  if (kDebugMode) {
    debugPrint('API error [${e.response?.statusCode}] ${e.requestOptions.path}');
  }

  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return "Server javob bermadi. Internetni tekshirib, qayta urinib ko'ring";
    case DioExceptionType.connectionError:
      return "Serverga ulanib bo'lmadi. API ishlayotganini tekshiring";
    case DioExceptionType.cancel:
      return "So'rov bekor qilindi";
    case DioExceptionType.badResponse:
      final parsed = _messageFromBody(e.response?.data);
      if (parsed != null && parsed.isNotEmpty) return parsed;
      final code = e.response?.statusCode;
      if (code == 401) return "Sessiya tugadi. Qayta kiring";
      if (code == 403) return "Ruxsat yo'q";
      if (code == 404) return "Ma'lumot topilmadi";
      if (code == 429) return "Juda ko'p urinish. Biroz kutib qayta urinib ko'ring";
      if (code != null && code >= 500) {
        return "Server xatosi. Keyinroq urinib ko'ring";
      }
      return "Xatolik yuz berdi. Qayta urinib ko'ring";
    default:
      return "Noma'lum xatolik. Qayta urinib ko'ring";
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

Error<String> dioToError(DioException e) => Error(mapDioError(e));

BaseResult successOrCatch(Response response) {
  return Success(response.data);
}
