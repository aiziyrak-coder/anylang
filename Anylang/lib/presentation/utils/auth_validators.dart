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
      'ACCOUNT_EXISTS_PASSWORD',
      'ACCOUNT_DELETED',
      'GOOGLE_ACCOUNT_CONFLICT',
      'ACCOUNT_NOT_VERIFIED',
      'INVALID_GOOGLE_TOKEN',
      'PAYMENT_PROVIDER_COMING_SOON',
      'SESSION_NOT_FOUND',
      'SESSION_PROTECT_WEEK',
      'CANNOT_REVOKE_CURRENT',
    ];
    for (final code in known) {
      if (raw.contains(code)) return code;
    }
    return null;
  }

  static bool hasErrorCode(Object? err, String code) =>
      apiErrorCode(err) == code;

  /// Session / devices API xatolari — lokalizatsiya.
  static String sessionError(Object? err, {String fallbackKey = 'error_generic'}) {
    final code = apiErrorCode(err);
    switch (code) {
      case 'SESSION_NOT_FOUND':
        return 'devices_error_session_not_found'.tr;
      case 'SESSION_PROTECT_WEEK':
        return 'devices_error_protect_week'.tr;
      case 'CANNOT_REVOKE_CURRENT':
        return 'devices_error_cannot_revoke_current'.tr;
      default:
        return safeError(err, fallbackKey: fallbackKey);
    }
  }

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
