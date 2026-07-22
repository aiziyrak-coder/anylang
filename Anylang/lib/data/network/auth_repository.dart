import 'package:dio/dio.dart';

import '../../presentation/utils/app_snackbar.dart';
import '../core/buildNetwork/base_result.dart';
import '../core/buildNetwork/error.dart';
import '../core/buildNetwork/network_client.dart';
import '../core/buildNetwork/success.dart';
import '../core/buildNetwork/utils.dart';
import '../local/session_store.dart';

/// AnyLang auth — email + parol + Google (TZ 3).
class AuthRepository {
  final NetworkClient _client;

  AuthRepository({required this._client});

  Future<BaseResult> register({
    required String fullName,
    required String email,
    required String password,
    required String birthDate,
    required String gender,
    required String country,
    required bool termsAccepted,
    String? appLanguage,
    String? nativeLanguage,
  }) {
    return _client.post(
      api: 'api/v1/auth/register',
      data: {
        'full_name': fullName,
        'email': email.trim().toLowerCase(),
        'password': password,
        'birth_date': birthDate,
        'gender': gender,
        'country': country,
        'terms_accepted': termsAccepted,
        'app_language': appLanguage ?? SessionStore.appLanguage(),
        'native_language': nativeLanguage ?? SessionStore.nativeLanguage(),
      },
      notify: SnackNotify.errors,
    );
  }

  Future<BaseResult> verifyEmail({
    required String email,
    required String code,
  }) async {
    final result = await _client.post(
      api: 'api/v1/auth/verify-email',
      data: {'email': email.trim().toLowerCase(), 'code': code},
      notify: SnackNotify.errors,
    );
    await _persistSession(result);
    return result;
  }

  Future<BaseResult> resendVerification({required String email}) {
    return _client.post(
      api: 'api/v1/auth/resend-verification',
      data: {
        'email': email.trim().toLowerCase(),
        'app_language': SessionStore.appLanguage(),
      },
      notify: SnackNotify.all,
    );
  }

  /// Login 403 ACCOUNT_NOT_VERIFIED holati — body'ni qaytaradi.
  Future<({BaseResult result, Map<String, dynamic>? body})> loginDetailed({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.apiService.dio.post(
        'api/v1/auth/login',
        data: {
          'email': email.trim().toLowerCase(),
          'password': password,
          'app_language': SessionStore.appLanguage(),
          'native_language': SessionStore.nativeLanguage(),
        },
      );
      final result = Success(response.data);
      await _persistSession(result);
      return (result: result, body: null);
    } on DioException catch (e) {
      final result = dioToError(e);
      showAppError(result.error);
      return (result: result, body: dioErrorBody(e));
    } catch (e) {
      showAppError("Noma'lum xatolik");
      return (result: Error("Noma'lum xatolik"), body: null);
    }
  }

  Future<BaseResult> loginWithGoogle({required String idToken}) async {
    final outcome = await loginWithGoogleDetailed(idToken: idToken);
    return outcome.result;
  }

  Future<({BaseResult result, Map<String, dynamic>? body})> loginWithGoogleDetailed({
    required String idToken,
  }) async {
    try {
      final response = await _client.apiService.dio.post(
        'api/v1/auth/google',
        data: {
          'id_token': idToken,
          'app_language': SessionStore.appLanguage(),
          'native_language': SessionStore.nativeLanguage(),
        },
      );
      final result = Success(response.data);
      await _persistSession(result);
      return (result: result, body: null);
    } on DioException catch (e) {
      final result = dioToError(e);
      showAppError(result.error);
      return (result: result, body: dioErrorBody(e));
    } catch (e) {
      showAppError("Google orqali kirib bo'lmadi");
      return (result: Error("Google orqali kirib bo'lmadi"), body: null);
    }
  }

  Future<BaseResult> logout() async {
    final refresh = SessionStore.refreshToken;
    final result = await _client.post(
      api: 'api/v1/auth/logout',
      data: {'refresh_token': refresh},
    );
    await SessionStore.clear();
    return result;
  }

  /// Soft-delete: akkaunt 365 kun saqlanadi, keyin anonymize purge.
  Future<BaseResult> deleteAccount({String? reason}) async {
    final result = await _client.delete(
      api: 'api/v1/users/me',
      data: {'reason': reason ?? 'user_requested'},
    );
    if (result.errorOrNull == null) {
      await SessionStore.clear();
    }
    return result;
  }

  /// O'chirilgan akkauntni tiklash arizasi (auth talab qilinmaydi).
  Future<BaseResult> submitRestoreRequest({
    required String email,
    String? number,
    required String reason,
  }) {
    return _client.post(
      api: 'api/v1/users/restore-request',
      data: {
        'email': email.trim().toLowerCase(),
        'number': number?.trim().isEmpty == true ? null : number?.trim(),
        'reason': reason.trim(),
      },
    );
  }

  Future<BaseResult> forgotPassword({required String email}) {
    return _client.post(
      api: 'api/v1/auth/password/forgot',
      data: {
        'email': email.trim().toLowerCase(),
        'app_language': SessionStore.appLanguage(),
      },
    );
  }

  Future<BaseResult> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) {
    return _client.post(
      api: 'api/v1/auth/password/reset',
      data: {
        'email': email.trim().toLowerCase(),
        'code': code,
        'new_password': newPassword,
      },
    );
  }

  Future<void> _persistSession(BaseResult result) async {
    final data = result.dataOrNull;
    if (data is! Map) return;
    final access = data['access_token'];
    final refresh = data['refresh_token'];
    if (access is String && refresh is String) {
      final user = data['user'];
      final expiresIn = data['expires_in'];
      await SessionStore.saveTokens(
        accessToken: access,
        refreshToken: refresh,
        user: user is Map ? Map<String, dynamic>.from(user) : null,
        expiresInSeconds: expiresIn is num ? expiresIn.toInt() : null,
      );
    }
  }
}
