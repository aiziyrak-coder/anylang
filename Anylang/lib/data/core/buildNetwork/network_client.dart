import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;

import '../../../presentation/utils/app_snackbar.dart';
import 'api_service.dart';
import 'base_result.dart';
import 'error.dart';
import 'success.dart';
import 'utils.dart';

/// Mutatsiya so'rovlarida snackbar qanday chiqishi.
enum SnackNotify {
  /// Hech narsa ko'rsatilmaydi (chat xabar, read va h.k.).
  none,

  /// Faqat xato.
  errors,

  /// Muvaffaqiyat + xato.
  all,
}

class NetworkClient {
  final ApiService apiService;

  NetworkClient({required this.apiService});

  Future<BaseResult> post({
    required String api,
    Object? data,
    Map<String, dynamic>? queryParameters,
    SnackNotify notify = SnackNotify.errors,
  }) async {
    return _mutate(
      notify: notify,
      call: () => apiService.dio.post(
        api,
        data: data,
        queryParameters: queryParameters,
      ),
    );
  }

  Future<BaseResult> get({
    required String api,
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await apiService.dio.get(
        api,
        data: data,
        queryParameters: queryParameters,
      );
      return Success(response.data);
    } on DioException catch (e) {
      return dioToError(e);
    } catch (e) {
      return Error("Noma'lum xatolik");
    }
  }

  Future<BaseResult> put({
    required String api,
    Object? data,
    Map<String, dynamic>? queryParameters,
    SnackNotify notify = SnackNotify.errors,
  }) async {
    return _mutate(
      notify: notify,
      call: () => apiService.dio.put(
        api,
        data: data,
        queryParameters: queryParameters,
      ),
    );
  }

  Future<BaseResult> patch({
    required String api,
    Object? data,
    Map<String, dynamic>? queryParameters,
    SnackNotify notify = SnackNotify.errors,
  }) async {
    return _mutate(
      notify: notify,
      call: () => apiService.dio.patch(
        api,
        data: data,
        queryParameters: queryParameters,
      ),
    );
  }

  Future<BaseResult> delete({
    required String api,
    Object? data,
    Map<String, dynamic>? queryParameters,
    SnackNotify notify = SnackNotify.errors,
  }) async {
    return _mutate(
      notify: notify,
      call: () => apiService.dio.delete(
        api,
        data: data,
        queryParameters: queryParameters,
      ),
    );
  }

  Future<BaseResult> _mutate({
    required SnackNotify notify,
    required Future<Response> Function() call,
  }) async {
    try {
      final response = await call();
      final result = Success(response.data);
      _toast(result, notify: notify);
      return result;
    } on DioException catch (e) {
      final result = dioToError(e);
      _toast(result, notify: notify);
      return result;
    } catch (e) {
      final result = Error("Noma'lum xatolik");
      _toast(result, notify: notify);
      return result;
    }
  }

  void _toast(BaseResult result, {required SnackNotify notify}) {
    if (notify == SnackNotify.none) return;

    result.when(
      success: (data) {
        if (notify != SnackNotify.all) return;
        final msg = successMessageFromBody(data) ?? 'action_done'.tr;
        showAppMessage(msg);
      },
      failure: (err) {
        if (notify == SnackNotify.none) return;
        showAppError(err);
      },
    );
  }
}
