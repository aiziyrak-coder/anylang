import 'package:latlong2/latlong.dart';

/// ISO alpha-2 → taxminiy markaz (xarita markerlari uchun).
const Map<String, LatLng> kCountryCentroids = {
  'AF': LatLng(33.9391, 67.7100),
  'AM': LatLng(40.0691, 45.0382),
  'AE': LatLng(23.4241, 53.8478),
  'AZ': LatLng(40.1431, 47.5769),
  'BD': LatLng(23.6850, 90.3563),
  'BR': LatLng(-14.2350, -51.9253),
  'CN': LatLng(35.8617, 104.1954),
  'DE': LatLng(51.1657, 10.4515),
  'EG': LatLng(26.8206, 30.8025),
  'ES': LatLng(40.4637, -3.7492),
  'FR': LatLng(46.2276, 2.2137),
  'GB': LatLng(55.3781, -3.4360),
  'GE': LatLng(42.3154, 43.3569),
  'ID': LatLng(-0.7893, 113.9213),
  'IN': LatLng(20.5937, 78.9629),
  'IR': LatLng(32.4279, 53.6880),
  'IT': LatLng(41.8719, 12.5674),
  'JP': LatLng(36.2048, 138.2529),
  'KG': LatLng(41.2044, 74.7661),
  'KR': LatLng(35.9078, 127.7669),
  'KZ': LatLng(48.0196, 66.9237),
  'MY': LatLng(4.2105, 101.9758),
  'PK': LatLng(30.3753, 69.3451),
  'PL': LatLng(51.9194, 19.1451),
  'RU': LatLng(61.5240, 105.3188),
  'SA': LatLng(23.8859, 45.0792),
  'TH': LatLng(15.8700, 100.9925),
  'TJ': LatLng(38.8610, 71.2761),
  'TM': LatLng(38.9697, 59.5563),
  'TR': LatLng(39.0, 35.0),
  'UA': LatLng(48.3794, 31.1656),
  'US': LatLng(37.0902, -95.7129),
  'UZ': LatLng(41.3775, 64.5853),
  'VN': LatLng(14.0583, 108.2772),
};

LatLng? centroidForCountry(String code) {
  final c = code.trim().toUpperCase();
  if (c.length != 2) return null;
  return kCountryCentroids[c];
}
