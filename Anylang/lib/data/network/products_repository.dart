import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import '../core/buildNetwork/base_result.dart';
import '../core/buildNetwork/network_client.dart';

class ProductsRepository {
  final NetworkClient _client;

  ProductsRepository({required NetworkClient client}) : _client = client;

  Future<BaseResult> list({
    int page = 1,
    int limit = 40,
    String? q,
    String? category,
    String? country,
    String? businessRole,
    bool verifiedOnly = false,
    bool readyStock = false,
    bool freeShipping = false,
    bool premiumSeller = false,
    bool newOnly = false,
    String sort = 'newest',
  }) {
    return _client.get(
      api: 'api/v1/products',
      queryParameters: {
        'page': page,
        'limit': limit,
        'sort': sort,
        if (q != null && q.isNotEmpty) 'search': q,
        if (category != null && category.isNotEmpty) 'category': category,
        if (country != null && country.isNotEmpty) 'country': country,
        if (businessRole != null && businessRole.isNotEmpty)
          'business_role': businessRole,
        if (verifiedOnly) 'verified_only': true,
        if (readyStock) 'ready_stock': true,
        if (freeShipping) 'free_shipping': true,
        if (premiumSeller) 'premium_seller': true,
        if (newOnly) 'new_only': true,
      },
    );
  }

  /// Avval ko‘rilgan mahsulotlar asosida shaxsiy tavsiyalar.
  Future<BaseResult> forYou({int limit = 12}) {
    return _client.get(
      api: 'api/v1/products/for-you',
      queryParameters: {'limit': limit},
    );
  }

  /// Xarita: ishlab chiqaruvchilar davlatlar bo‘yicha.
  Future<BaseResult> manufacturersMap() {
    return _client.get(api: 'api/v1/products/manufacturers-map');
  }

  /// Tabiiy til qidiruvi: "Turkey textile factory" → filtrlar + mahsulotlar.
  Future<BaseResult> smartSearch({
    required String q,
    String locale = 'uz',
    int page = 1,
    int limit = 40,
  }) {
    return _client.get(
      api: 'api/v1/products/smart-search',
      queryParameters: {
        'q': q,
        'locale': locale,
        'page': page,
        'limit': limit,
      },
    );
  }

  Future<BaseResult> listMine({int page = 1, int limit = 40}) {
    return _client.get(
      api: 'api/v1/users/me/products',
      queryParameters: {'page': page, 'limit': limit},
    );
  }

  Future<BaseResult> top({int limit = 10}) {
    return _client.get(
      api: 'api/v1/products/top',
      queryParameters: {'limit': limit},
    );
  }

  Future<BaseResult> detail(int productId) {
    return _client.get(api: 'api/v1/products/$productId');
  }

  Future<BaseResult> categories({String language = 'uz_UZ'}) {
    return _client.get(
      api: 'api/v1/products/categories',
      queryParameters: {'language': language},
    );
  }

  Future<MultipartFile> _imagePart(String filePath) async {
    final name = filePath.split(RegExp(r'[\\/]')).last;
    final mime = lookupMimeType(filePath) ??
        lookupMimeType(name) ??
        'image/jpeg';
    final parts = mime.split('/');
    final filename = name.contains('.') ? name : '$name.jpg';
    return MultipartFile.fromFile(
      filePath,
      filename: filename,
      contentType: MediaType(
        parts.isNotEmpty ? parts[0] : 'image',
        parts.length > 1 ? parts[1] : 'jpeg',
      ),
    );
  }

  Future<BaseResult> uploadImage(String filePath) async {
    final form = FormData.fromMap({
      'file': await _imagePart(filePath),
    });
    return _client.post(
      api: 'api/v1/products/images',
      data: form,
      notify: SnackNotify.none,
    );
  }

  Future<MultipartFile> _videoPart(String filePath) async {
    final name = filePath.split(RegExp(r'[\\/]')).last;
    final mime = lookupMimeType(filePath) ??
        lookupMimeType(name) ??
        'video/mp4';
    final parts = mime.split('/');
    final filename = name.contains('.') ? name : '$name.mp4';
    return MultipartFile.fromFile(
      filePath,
      filename: filename,
      contentType: MediaType(
        parts.isNotEmpty ? parts[0] : 'video',
        parts.length > 1 ? parts[1] : 'mp4',
      ),
    );
  }

  /// Qisqa mahsulot videosi (≈15s) yuklash → `{ url }`.
  Future<BaseResult> uploadVideo(String filePath) async {
    final form = FormData.fromMap({
      'file': await _videoPart(filePath),
    });
    return _client.post(
      api: 'api/v1/products/videos',
      data: form,
      notify: SnackNotify.none,
    );
  }

  Future<BaseResult> create(Map<String, dynamic> body) {
    return _client.post(api: 'api/v1/products', data: body);
  }

  Future<BaseResult> update(int productId, Map<String, dynamic> body) {
    return _client.patch(api: 'api/v1/products/$productId', data: body);
  }

  Future<BaseResult> archive(int productId) {
    return _client.delete(api: 'api/v1/products/$productId');
  }

  Future<BaseResult> listByUser(int userId, {int page = 1, int limit = 40}) {
    return _client.get(
      api: 'api/v1/users/$userId/products',
      queryParameters: {'page': page, 'limit': limit},
    );
  }

  Future<BaseResult> listFavorites({int page = 1, int limit = 40}) {
    return _client.get(
      api: 'api/v1/users/me/favorites',
      queryParameters: {'page': page, 'limit': limit},
    );
  }

  Future<BaseResult> favorite(int id) {
    return _client.post(api: 'api/v1/products/$id/favorite');
  }

  Future<BaseResult> unfavorite(int id) {
    return _client.delete(api: 'api/v1/products/$id/favorite');
  }

  Future<BaseResult> requestTop(int productId, {String note = ''}) {
    return _client.post(
      api: 'api/v1/products/$productId/top-request',
      data: {'note': note},
    );
  }

  Future<BaseResult> cancelTopRequest(int productId) {
    return _client.delete(api: 'api/v1/products/$productId/top-request');
  }
}
