/// Backend manzili (trailing slash Dio path join uchun muhim).
///
/// Production default: https://anylang.uz/
/// Local override:
/// `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/`
const String kBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://anylang.uz/',
);

/// Token yangilash endpoint'i (baseUrl'ga nisbatan).
const String kRefreshTokenApi = 'api/v1/auth/refresh';

/// Release build'da localhost / cleartext API bloklanadi.
void assertProductionApiConfig() {
  const isRelease = bool.fromEnvironment('dart.vm.product');
  if (!isRelease) return;
  final uri = Uri.tryParse(kBaseUrl);
  final host = uri?.host ?? '';
  final isLoopback = host == '127.0.0.1' || host == 'localhost' || host == '::1';
  if (isLoopback || uri?.scheme != 'https') {
    throw StateError(
      'Release build requires --dart-define=API_BASE_URL=https://... '
      '(got "$kBaseUrl")',
    );
  }
}
