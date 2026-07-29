import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/core/maps_config.dart';
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

/// Telegram uslubidagi joylashuv tanlash sheet'i (Google Maps).
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
  final _places = PlacesService();
  final _searchCtrl = TextEditingController();
  final Completer<GoogleMapController> _mapReady =
      Completer<GoogleMapController>();

  GoogleMapController? _map;
  LatLng? _myPos;
  double? _accuracy;
  LatLng _center = const LatLng(41.3111, 69.2797);
  bool _loadingGps = true;
  bool _loadingPlaces = false;
  bool _searching = false;
  bool _cameraMoving = false;
  List<NearbyPlace> _nearby = const [];
  List<NearbyPlace> _searchHits = const [];
  String? _pinLabel;
  Timer? _moveDebounce;

  static const _darkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#242f3e"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#746855"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#242f3e"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},
  {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#263c3f"}]},
  {"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#6b9a76"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#38414e"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#212a37"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#9ca5b3"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#746855"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#1f2835"}]},
  {"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#f3d19c"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#2f3948"}]},
  {"featureType":"transit.station","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#17263c"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#515c6d"}]},
  {"featureType":"water","elementType":"labels.text.stroke","stylers":[{"color":"#17263c"}]}
]
''';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _moveDebounce?.cancel();
    _searchCtrl.dispose();
    _map?.dispose();
    super.dispose();
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    _map = controller;
    if (!_mapReady.isCompleted) _mapReady.complete(controller);
    if (_myPos != null) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(_myPos!, 16),
      );
    }
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
      final map = _map ??
          await _mapReady.future.timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw TimeoutException('map'),
          );
      await map.animateCamera(CameraUpdate.newLatLngZoom(ll, 16));
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

  void _onCameraMove(CameraPosition pos) {
    _center = pos.target;
    _cameraMoving = true;
  }

  void _onCameraIdle() {
    if (!_cameraMoving) return;
    _cameraMoving = false;
    final target = _center;
    _moveDebounce?.cancel();
    _moveDebounce = Timer(const Duration(milliseconds: 450), () {
      unawaited(_refreshPinLabel(target));
      unawaited(_refreshPlaces(target));
    });
  }

  Future<void> _recenter() async {
    if (_myPos != null) {
      final map = _map;
      if (map != null) {
        await map.animateCamera(CameraUpdate.newLatLngZoom(_myPos!, 16));
      }
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
      final res = await _places.searchPlaces(
        query: q,
        nearLat: _center.latitude,
        nearLng: _center.longitude,
      );
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

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final h = MediaQuery.sizeOf(context).height;
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final isDark = c.isDark;
    final sheetBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

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
          if (!MapsConfig.isConfigured)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.dp, vertical: 4.dp),
              child: Text(
                'location_maps_key_missing'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 11.sp,
                ),
              ),
            ),
          Expanded(
            flex: 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(0),
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _center,
                      zoom: 15,
                    ),
                    onMapCreated: _onMapCreated,
                    onCameraMove: _onCameraMove,
                    onCameraIdle: _onCameraIdle,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    compassEnabled: false,
                    mapToolbarEnabled: false,
                    mapType: MapType.normal,
                    style: isDark ? _darkMapStyle : null,
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
    final k = kind.toLowerCase();
    if (k.contains('restaurant') ||
        k.contains('cafe') ||
        k.contains('food') ||
        k.contains('bar') ||
        k.contains('meal')) {
      return Icons.restaurant_rounded;
    }
    if (k.contains('hospital') ||
        k.contains('clinic') ||
        k.contains('pharmacy') ||
        k.contains('health') ||
        k.contains('doctor')) {
      return Icons.local_hospital_rounded;
    }
    if (k.contains('school') ||
        k.contains('university') ||
        k.contains('college')) {
      return Icons.school_rounded;
    }
    if (k.contains('hotel') || k.contains('lodging') || k.contains('motel')) {
      return Icons.hotel_rounded;
    }
    if (k.contains('gas') || k.contains('fuel')) {
      return Icons.local_gas_station_rounded;
    }
    if (k.contains('bank') || k.contains('atm') || k.contains('finance')) {
      return Icons.account_balance_rounded;
    }
    if (k.contains('park') || k.contains('garden')) {
      return Icons.park_rounded;
    }
    if (k.contains('store') ||
        k.contains('shop') ||
        k.contains('mall') ||
        k.contains('supermarket')) {
      return Icons.storefront_rounded;
    }
    return Icons.place_rounded;
  }

  Color _colorForKind(String kind) {
    final k = kind.toLowerCase();
    if (k.contains('restaurant') ||
        k.contains('cafe') ||
        k.contains('food') ||
        k.contains('bar')) {
      return const Color(0xFFFF9500);
    }
    if (k.contains('hospital') ||
        k.contains('clinic') ||
        k.contains('pharmacy') ||
        k.contains('health')) {
      return const Color(0xFFFF3B30);
    }
    if (k.contains('school') ||
        k.contains('university') ||
        k.contains('college')) {
      return const Color(0xFFAF52DE);
    }
    if (k.contains('hotel') || k.contains('lodging')) {
      return const Color(0xFF5856D6);
    }
    if (k.contains('gas') || k.contains('fuel')) {
      return const Color(0xFF8E8E93);
    }
    if (k.contains('bank') || k.contains('atm')) {
      return const Color(0xFF34C759);
    }
    if (k.contains('park') || k.contains('garden')) {
      return const Color(0xFF30D158);
    }
    return const Color(0xFFFF9500);
  }
}
