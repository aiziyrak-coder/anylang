import 'dart:io';

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

/// Bayroq PNG: birinchi yuklash → disk cache, keyingi safar fayldan.
class FlagCacheService extends GetxService {
  final Dio _dio;
  final Map<String, Future<File?>> _inflight = {};
  Directory? _dir;

  FlagCacheService({Dio? dio}) : _dio = dio ?? Dio();

  Future<FlagCacheService> init() async {
    final root = await getApplicationSupportDirectory();
    _dir = Directory('${root.path}/flags');
    if (!await _dir!.exists()) {
      await _dir!.create(recursive: true);
    }
    return this;
  }

  Future<File?> getFile(String url) {
    final key = url.trim();
    if (key.isEmpty) return Future.value(null);
    return _inflight.putIfAbsent(key, () => _load(key));
  }

  Future<File?> _load(String url) async {
    try {
      final dir = _dir;
      if (dir == null) return null;
      final name = _fileName(url);
      final file = File('${dir.path}/$name');
      if (await file.exists() && await file.length() > 0) {
        return file;
      }
      final tmp = File('${dir.path}/.$name.tmp');
      await _dio.download(
        url,
        tmp.path,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 10),
        ),
      );
      if (await file.exists()) {
        await file.delete();
      }
      await tmp.rename(file.path);
      return file;
    } catch (_) {
      return null;
    } finally {
      _inflight.remove(url);
    }
  }

  String _fileName(String url) {
    final uri = Uri.tryParse(url);
    final last = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : url.hashCode.toRadixString(16);
    final safe = last.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return safe.isEmpty ? 'flag_${url.hashCode}.png' : safe;
  }
}
