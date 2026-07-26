import 'package:get/get.dart';

/// Auth forma validatsiyasi — login / register / forgot / restore uchun bir xil.
abstract final class AuthValidators {
  static bool isValidEmail(String email) {
    final v = email.trim();
    if (v.length < 5 || !v.contains('@') || !v.contains('.')) return false;
    // Oddiy RFC-ish: local@domain.tld
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
  }

  static String? emailError(String email) {
    if (isValidEmail(email)) return null;
    return 'email_invalid'.tr;
  }

  static bool isStrongPassword(String password) {
    if (password.length < 8) return false;
    return RegExp(r'[A-Za-z]').hasMatch(password) &&
        RegExp(r'\d').hasMatch(password);
  }

  static String? passwordError(String password) {
    if (password.length < 8) return 'password_short'.tr;
    if (!isStrongPassword(password)) return 'password_weak'.tr;
    return null;
  }

  /// Login: faqat bo‘sh emas — kuch talabi register/reset uchun.
  static String? loginPasswordError(String password) {
    if (password.isEmpty) return 'password_required'.tr;
    return null;
  }

  /// Dio `error_code` yoki `[CODE]` qo‘shimchasidan kod.
  static String? apiErrorCode(Object? err) {
    final raw = err?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    final bracket = RegExp(r'\[([A-Z0-9_]+)\]').firstMatch(raw);
    if (bracket != null) return bracket.group(1);
    const known = [
      'REQUEST_ALREADY_SENT',
      'NOT_A_BUSINESS',
      'SUBSCRIPTION_REQUIRED',
      'PREMIUM_REQUIRED',
    ];
    for (final code in known) {
      if (raw.contains(code)) return code;
    }
    return null;
  }

  static bool hasErrorCode(Object? err, String code) =>
      apiErrorCode(err) == code;

  /// API / catch xabarlarini foydalanuvchiga xavfsiz ko‘rsatish.
  static String safeError(Object? err, {String fallbackKey = 'unknown_error'}) {
    final raw = err?.toString().trim() ?? '';
    if (raw.isEmpty) return fallbackKey.tr;
    // Dio / Exception prefixlarini yashirish.
    if (raw.startsWith('Exception:') ||
        raw.startsWith('Error:') ||
        raw.contains('SocketException') ||
        raw.contains('DioException')) {
      return fallbackKey.tr;
    }
    return raw;
  }
}
