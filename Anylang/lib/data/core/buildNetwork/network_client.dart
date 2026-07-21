import 'package:dio/dio.dart';

import 'api_service.dart';
import 'base_result.dart';
import 'error.dart';
import 'success.dart';
import 'utils.dart';

class NetworkClient {
  final ApiService apiService;

  NetworkClient({required this.apiService});

  Future<BaseResult> post({
    required String api,
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await apiService.dio.post(
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
  }) async {
    try {
      final response = await apiService.dio.put(
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

  Future<BaseResult> patch({
    required String api,
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await apiService.dio.patch(
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

  Future<BaseResult> delete({
    required String api,
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await apiService.dio.delete(
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
}
