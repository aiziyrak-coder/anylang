/// Google Maps / Places API kaliti.
///
/// Manbalar (birinchisi topilgan ishlatiladi):
/// 1) `--dart-define=GOOGLE_MAPS_API_KEY=...` (Places REST + runtime)
/// 2) Android `local.properties` → Manifest (native Maps SDK)
///
/// Kalitni Google Cloud Console da yarating:
/// https://console.cloud.google.com/google/maps-apis/credentials
/// Yoqing: Maps SDK for Android, Maps SDK for iOS, Places API, Geocoding API.
class MapsConfig {
  static const String apiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  static bool get isConfigured => apiKey.trim().isNotEmpty;
}
