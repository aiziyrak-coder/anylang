import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/network/places_service.dart';
import '../ui/theme/colors.dart';
import '../utils/app_snackbar.dart';
import '../utils/size_controller.dart';

/// Joylashuv tanlash natijasi — chatga yuboriladi.
class LocationPickResult {
  final double latitude;
  final double longitude;
  final String label;
  final double? accuracyMeters;

  const LocationPickResult({
    required this.latitude,
    required this.longitude,
    required this.label,
    this.accuracyMeters,
  });
}

/// Telegram uslubidagi joylashuv tanlash sheet'i.
Future<LocationPickResult?> showLocationPickerBottomSheet(
  BuildContext context,
) {
  return showModalBottomSheet<LocationPickResult>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _LocationPickerSheet(),
  );
}

class _LocationPickerSheet extends StatefulWidget {
  const _LocationPickerSheet();

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  final _map = MapController();
  final _places = PlacesService();
  final _searchCtrl = TextEditingController();

  LatLng? _myPos;
  double? _accuracy;
  LatLng _center = const LatLng(41.3111, 69.2797);
  bool _loadingGps = true;
  bool _loadingPlaces = false;
  bool _searching = false;
  List<NearbyPlace> _nearby = const [];
  List<NearbyPlace> _searchHits = const [];
  String? _pinLabel;
  Timer? _moveDebounce;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _moveDebounce?.cancel();
    _searchCtrl.dispose();
    _map.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) {
      if (mounted) {
        setState(() => _loadingGps = false);
        showAppMessage('location_permission_needed'.tr);
      }
      return;
    }
    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) {
      if (mounted) {
        setState(() => _loadingGps = false);
        showAppMessage('location_gps_off'.tr);
      }
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      final ll = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _myPos = ll;
        _center = ll;
        _accuracy = pos.accuracy;
        _loadingGps = false;
      });
      _map.move(ll, 16);
      unawaited(_refreshPlaces(ll));
      unawaited(_refreshPinLabel(ll));
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingGps = false);
      showAppMessage('location_fetch_failed'.tr);
    }
  }

  Future<void> _refreshPinLabel(LatLng ll) async {
    final label = await _places.reverseGeocode(
      latitude: ll.latitude,
      longitude: ll.longitude,
    );
    if (!mounted) return;
    setState(() => _pinLabel = label);
  }

  Future<void> _refreshPlaces(LatLng ll) async {
    setState(() => _loadingPlaces = true);
    final items = await _places.nearbyPlaces(
      latitude: ll.latitude,
      longitude: ll.longitude,
    );
    if (!mounted) return;
    setState(() {
      _nearby = items;
      _loadingPlaces = false;
    });
  }

  void _onMapMoved(MapCamera cam, bool hasGesture) {
    _center = cam.center;
    if (!hasGesture) return;
    _moveDebounce?.cancel();
    _moveDebounce = Timer(const Duration(milliseconds: 450), () {
      unawaited(_refreshPinLabel(cam.center));
      unawaited(_refreshPlaces(cam.center));
    });
  }

  Future<void> _recenter() async {
    if (_myPos != null) {
      _map.move(_myPos!, 16);
      setState(() => _center = _myPos!);
      return;
    }
    setState(() => _loadingGps = true);
    await _bootstrap();
  }

  void _sendCurrent() {
    final pos = _myPos ?? _center;
    Navigator.pop(
      context,
      LocationPickResult(
        latitude: pos.latitude,
        longitude: pos.longitude,
        label: 'chat_my_location'.tr,
        accuracyMeters: _accuracy,
      ),
    );
  }

  void _sendPin() {
    final label = (_pinLabel != null && _pinLabel!.trim().isNotEmpty)
        ? _pinLabel!.trim()
        : 'chat_my_location'.tr;
    Navigator.pop(
      context,
      LocationPickResult(
        latitude: _center.latitude,
        longitude: _center.longitude,
        label: label,
      ),
    );
  }

  void _sendPlace(NearbyPlace place) {
    Navigator.pop(
      context,
      LocationPickResult(
        latitude: place.latitude,
        longitude: place.longitude,
        label: place.name,
      ),
    );
  }

  Future<void> _runSearch(String raw) async {
    final q = raw.trim();
    if (q.length < 2) {
      setState(() {
        _searchHits = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final res = await _nominatimSearch(query: q, near: _center);
      if (!mounted) return;
      setState(() {
        _searchHits = res;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searchHits = const [];
        _searching = false;
      });
    }
  }

  Future<List<NearbyPlace>> _nominatimSearch({
    required String query,
    required LatLng near,
  }) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 12),
        headers: const {
          'User-Agent': 'AnyLang/1.0 (https://anylang.uz; support@anylang.uz)',
          'Accept-Language': 'uz,ru,en',
        },
      ),
    );
    const delta = 0.08;
    final res = await dio.get(
      'https://nominatim.openstreetmap.org/search',
      queryParameters: {
        'q': query,
        'format': 'jsonv2',
        'limit': 15,
        'addressdetails': 1,
        'viewbox':
            '${near.longitude - delta},${near.latitude + delta},${near.longitude + delta},${near.latitude - delta}',
        'bounded': 0,
      },
    );
    final list = res.data;
    if (list is! List) return const [];
    return list.whereType<Map>().map((e) {
      final name = e['display_name']?.toString() ?? e['name']?.toString() ?? '';
      final short = name.split(',').first.trim();
      return NearbyPlace(
        name: short.isNotEmpty ? short : name,
        address: name,
        latitude: double.tryParse('${e['lat']}') ?? near.latitude,
        longitude: double.tryParse('${e['lon']}') ?? near.longitude,
        kind: e['type']?.toString() ?? 'place',
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final h = MediaQuery.sizeOf(context).height;
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final isDark = c.isDark;
    final sheetBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final mapUrl = isDark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    final mapSubs = isDark ? const ['a', 'b', 'c', 'd'] : const <String>[];

    return Container(
      height: h * 0.92,
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18.dp)),
      ),
      child: Column(
        children: [
          SizedBox(height: 8.dp),
          Container(
            width: 36.dp,
            height: 4.dp,
            decoration: BoxDecoration(
              color: c.outline,
              borderRadius: BorderRadius.circular(4.dp),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(8.dp, 8.dp, 8.dp, 4.dp),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: c.textPrimary),
                ),
                Expanded(
                  child: Text(
                    'location_sheet_title'.tr,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: sheetBg,
                        title: Text('location_search'.tr),
                        content: TextField(
                          controller: _searchCtrl,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'location_search_hint'.tr,
                          ),
                          onSubmitted: (v) {
                            Navigator.pop(ctx);
                            unawaited(_runSearch(v));
                          },
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text('common_cancel'.tr),
                          ),
                          TextButton(
                            onPressed: () {
                              final v = _searchCtrl.text;
                              Navigator.pop(ctx);
                              unawaited(_runSearch(v));
                            },
                            child: Text('common_search'.tr),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: Icon(Icons.search_rounded, color: c.textPrimary),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 15,
                    onPositionChanged: _onMapMoved,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: mapUrl,
                      subdomains: mapSubs,
                      userAgentPackageName: 'com.izodev.anylang',
                    ),
                    if (_myPos != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _myPos!,
                            width: 22,
                            height: 22,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF3390EC),
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF3390EC)
                                        .withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                IgnorePointer(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 28.dp),
                      child: Icon(
                        Icons.location_on_rounded,
                        size: 44.dp,
                        color: const Color(0xFFE53935),
                        shadows: const [
                          Shadow(
                            color: Color(0x66000000),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 12.dp,
                  bottom: 12.dp,
                  child: _mapFab(
                    c,
                    icon: Icons.my_location_rounded,
                    onTap: _recenter,
                  ),
                ),
                if (_loadingGps)
                  Positioned.fill(
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.18),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 6,
            child: ListView(
              padding: EdgeInsets.fromLTRB(8.dp, 8.dp, 8.dp, 12.dp + bottom),
              children: [
                if (_searchHits.isNotEmpty || _searching) ...[
                  if (_searching)
                    Padding(
                      padding: EdgeInsets.all(16.dp),
                      child: const Center(child: CircularProgressIndicator()),
                    )
                  else
                    ..._searchHits.map(
                      (p) => _placeTile(
                        c,
                        icon: Icons.place_rounded,
                        iconBg: const Color(0xFF3390EC),
                        title: p.name,
                        subtitle: p.address,
                        onTap: () => _sendPlace(p),
                      ),
                    ),
                  Divider(color: c.outline, height: 20.dp),
                ],
                _placeTile(
                  c,
                  icon: Icons.my_location_rounded,
                  iconBg: const Color(0xFF3390EC),
                  title: 'location_send_current'.tr,
                  subtitle: _accuracy != null
                      ? 'location_accuracy'
                          .trParams({'m': _accuracy!.round().toString()})
                      : (_pinLabel ?? 'location_accuracy_approx'.tr),
                  onTap: _sendCurrent,
                ),
                _placeTile(
                  c,
                  icon: Icons.sensors_rounded,
                  iconBg: const Color(0xFF34C759),
                  title: 'location_live_share'.tr,
                  subtitle: 'location_live_hint'.tr,
                  onTap: () => showAppMessage('location_live_soon'.tr),
                ),
                if ((_pinLabel ?? '').isNotEmpty)
                  _placeTile(
                    c,
                    icon: Icons.push_pin_rounded,
                    iconBg: const Color(0xFFE53935),
                    title: 'location_send_pin'.tr,
                    subtitle: _pinLabel,
                    onTap: _sendPin,
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(12.dp, 14.dp, 12.dp, 6.dp),
                  child: Text(
                    'location_or_choose'.tr.toUpperCase(),
                    style: TextStyle(
                      color: c.textFaint,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                if (_loadingPlaces)
                  Padding(
                    padding: EdgeInsets.all(20.dp),
                    child: const Center(child: CircularProgressIndicator()),
                  )
                else if (_nearby.isEmpty)
                  Padding(
                    padding: EdgeInsets.all(16.dp),
                    child: Text(
                      'location_places_empty'.tr,
                      style:
                          TextStyle(color: c.textSecondary, fontSize: 13.sp),
                    ),
                  )
                else
                  ..._nearby.map(
                    (p) => _placeTile(
                      c,
                      icon: _iconForKind(p.kind),
                      iconBg: _colorForKind(p.kind),
                      title: p.name,
                      subtitle: p.address,
                      onTap: () => _sendPlace(p),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(12.dp, 8.dp, 12.dp, 4.dp),
                  child: Text(
                    '© OpenStreetMap',
                    style: TextStyle(color: c.textFaint, fontSize: 10.sp),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapFab(
    AppColors c, {
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: c.isDark ? const Color(0xFF2C2C2E) : Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44.dp,
          height: 44.dp,
          child: Icon(icon, color: const Color(0xFF3390EC), size: 22.dp),
        ),
      ),
    );
  }

  Widget _placeTile(
    AppColors c, {
    required IconData icon,
    required Color iconBg,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.dp, vertical: 10.dp),
          child: Row(
            children: [
              Container(
                width: 44.dp,
                height: 44.dp,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 22.dp),
              ),
              SizedBox(width: 12.dp),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                      SizedBox(height: 2.dp),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 13.sp,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForKind(String kind) {
    return switch (kind) {
      'restaurant' || 'cafe' || 'fast_food' || 'bar' || 'pub' =>
        Icons.restaurant_rounded,
      'hospital' || 'clinic' || 'pharmacy' => Icons.local_hospital_rounded,
      'school' || 'university' || 'college' => Icons.school_rounded,
      'hotel' || 'motel' || 'hostel' => Icons.hotel_rounded,
      'fuel' => Icons.local_gas_station_rounded,
      'bank' || 'atm' => Icons.account_balance_rounded,
      'park' || 'garden' => Icons.park_rounded,
      'supermarket' || 'convenience' || 'mall' => Icons.storefront_rounded,
      _ => Icons.place_rounded,
    };
  }

  Color _colorForKind(String kind) {
    return switch (kind) {
      'restaurant' || 'cafe' || 'fast_food' || 'bar' || 'pub' =>
        const Color(0xFFFF9500),
      'hospital' || 'clinic' || 'pharmacy' => const Color(0xFFFF3B30),
      'school' || 'university' || 'college' => const Color(0xFFAF52DE),
      'hotel' || 'motel' || 'hostel' => const Color(0xFF5856D6),
      'fuel' => const Color(0xFF8E8E93),
      'bank' || 'atm' => const Color(0xFF34C759),
      'park' || 'garden' => const Color(0xFF30D158),
      _ => const Color(0xFFFF9500),
    };
  }
}
