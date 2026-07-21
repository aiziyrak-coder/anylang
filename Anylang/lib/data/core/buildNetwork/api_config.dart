/// Backend manzili.
///
/// Override majburiy productionda:
/// `flutter run --dart-define=API_BASE_URL=https://api.example.com`
///
/// Local default faqat debug uchun.
const String kBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8000',
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
