// Backend manzili (trailing slash Dio path join uchun muhim).
//
// Qoidalar:
// - Release / Play AAB → har doim production: kProdApiBaseUrl
// - Debug / Profile → default kDevApiBaseUrl (dev server)
// - Majburiy override: --dart-define=API_BASE_URL=https://...
// - Env tanlash: --dart-define=APP_ENV=prod|dev

/// Production API (Play Market release shu yerga ulanadi).
const String kProdApiBaseUrl = 'https://anylang.uz/';

/// Development / staging API (faqat debug/profile).
const String kDevApiBaseUrl = 'https://dev.anylang.uz/';

const String _apiBaseOverride = String.fromEnvironment('API_BASE_URL');
const String _appEnvDefine = String.fromEnvironment('APP_ENV');

/// `dart.vm.product == true` → release (AAB/APK --release).
const bool kIsReleaseBuild = bool.fromEnvironment('dart.vm.product');

/// Qaysi muhitga ulanganmiz.
enum AppApiEnv { prod, dev, custom }

AppApiEnv get kResolvedApiEnv {
  if (_apiBaseOverride.trim().isNotEmpty) {
    final host = Uri.tryParse(_normalizeBase(_apiBaseOverride))?.host ?? '';
    if (host == 'anylang.uz' || host == 'www.anylang.uz') {
      return AppApiEnv.prod;
    }
    if (host == 'dev.anylang.uz' || host == 'staging.anylang.uz') {
      return AppApiEnv.dev;
    }
    return AppApiEnv.custom;
  }
  final env = _appEnvDefine.trim().toLowerCase();
  if (kIsReleaseBuild || env == 'prod' || env == 'production') {
    return AppApiEnv.prod;
  }
  if (env == 'dev' || env == 'development' || env == 'staging') {
    return AppApiEnv.dev;
  }
  // Debug/profile default → dev.
  return AppApiEnv.dev;
}

/// Faol API base URL (trailing slash bilan).
String get kBaseUrl {
  if (_apiBaseOverride.trim().isNotEmpty) {
    return _normalizeBase(_apiBaseOverride);
  }
  return kResolvedApiEnv == AppApiEnv.prod ? kProdApiBaseUrl : kDevApiBaseUrl;
}

bool get kIsDevApi => kResolvedApiEnv == AppApiEnv.dev;

String _normalizeBase(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return kProdApiBaseUrl;
  if (!s.endsWith('/')) s = '$s/';
  return s;
}

/// Token yangilash endpoint'i (baseUrl'ga nisbatan).
const String kRefreshTokenApi = 'api/v1/auth/refresh';

/// Release build'da faqat production HTTPS ruxsat etiladi.
void assertProductionApiConfig() {
  if (!kIsReleaseBuild) return;
  final uri = Uri.tryParse(kBaseUrl);
  final host = uri?.host ?? '';
  final isProdHost = host == 'anylang.uz' || host == 'www.anylang.uz';
  if (uri?.scheme != 'https' || !isProdHost) {
    throw StateError(
      'Release build MUST use production API ($kProdApiBaseUrl). '
      'Got "$kBaseUrl". Do not pass APP_ENV=dev / API_BASE_URL=dev for release.',
    );
  }
}
