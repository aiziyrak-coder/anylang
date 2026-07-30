import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/local/countries_service.dart';
import '../../ui/app_empty_state.dart';
import '../../ui/app_loading.dart';
import '../../ui/app_top_bar.dart';
import '../../ui/buttons/primary_button.dart';
import '../../ui/gradient_background.dart';
import '../../ui/theme/colors.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import 'country_centroids.dart';
import 'market_map_action.dart';
import 'market_map_country.dart';
import 'market_map_state.dart';

class MarketMapContent extends ScreenContent<MarketMapState> {
  final MapController _mapController = MapController();

  @override
  void onClose() {
    _mapController.dispose();
  }

  @override
  Widget build(
    BuildContext context,
    MarketMapState state,
    FutureOr<void> Function(MyAction action) sendAction,
  ) {
    final c = context.appColors;
    final isDark = c.isDark;
    final mapUrl = isDark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    final mapSubs = isDark ? const ['a', 'b', 'c', 'd'] : const <String>[];

    return GradientBackground(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.dp, 4.dp, 8.dp, 0),
              child: AppTopBar(
                title: 'products_map_view_title'.tr,
                onBack: () => sendAction(Back()),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20.dp, 6.dp, 20.dp, 8.dp),
              child: Obx(
                () => Text(
                  state.totalManufacturers.value > 0
                      ? 'products_map_view_subtitle'.trParams({
                          'n': '${state.totalManufacturers.value}',
                          'c': '${state.countries.length}',
                        })
                      : 'products_map_view_hint'.tr,
                  style: TextStyle(color: c.textSecondary, fontSize: 13.sp),
                ),
              ),
            ),
            Expanded(
              child: Obx(() {
                if (state.loading.value) {
                  return const Center(child: AppLoading());
                }
                final items = state.countries.toList();
                if (items.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.public_outlined,
                    title: 'products_map_view_empty'.tr,
                    subtitle: 'products_map_view_hint'.tr,
                  );
                }
                // countries o‘zgarganda qayta chiziladi; selected — alohida Obx
                return _MapBody(
                  mapController: _mapController,
                  mapUrl: mapUrl,
                  mapSubs: mapSubs,
                  countries: items,
                  state: state,
                  sendAction: sendAction,
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapBody extends StatelessWidget {
  final MapController mapController;
  final String mapUrl;
  final List<String> mapSubs;
  final List<MarketMapCountry> countries;
  final MarketMapState state;
  final FutureOr<void> Function(MyAction action) sendAction;

  const _MapBody({
    required this.mapController,
    required this.mapUrl,
    required this.mapSubs,
    required this.countries,
    required this.state,
    required this.sendAction,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: const LatLng(28, 70),
            initialZoom: 2.6,
            minZoom: 1.8,
            maxZoom: 8,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onTap: (_, _) => state.selected.value = null,
          ),
          children: [
            TileLayer(
              urlTemplate: mapUrl,
              subdomains: mapSubs,
              userAgentPackageName: 'com.cradev.anylang',
            ),
            Obx(() {
              final selectedCode = state.selected.value?.country;
              final markers = <Marker>[];
              for (final item in countries) {
                final point = centroidForCountry(item.country);
                if (point == null) continue;
                markers.add(
                  Marker(
                    point: point,
                    width: 86.dp,
                    height: 56.dp,
                    alignment: Alignment.bottomCenter,
                    child: _CountryMarker(
                      country: item,
                      selected: selectedCode == item.country,
                      onTap: () => sendAction(MarketMapSelectCountry(item)),
                    ),
                  ),
                );
              }
              return MarkerLayer(markers: markers);
            }),
          ],
        ),
        Obx(() {
          final selected = state.selected.value;
          if (selected == null) return const SizedBox.shrink();
          return Positioned(
            left: 16.dp,
            right: 16.dp,
            bottom: 16.dp,
            child: _CountrySheet(
              country: selected,
              onClose: () => state.selected.value = null,
              onViewProducts: () =>
                  sendAction(MarketMapViewProducts(selected.country)),
              onOpenCompany: (id) => sendAction(MarketMapOpenCompany(id)),
            ),
          );
        }),
      ],
    );
  }
}

class _CountryMarker extends StatelessWidget {
  final MarketMapCountry country;
  final bool selected;
  final VoidCallback onTap;

  const _CountryMarker({
    required this.country,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final opt = Get.find<CountriesService>().findByCode(country.country);
    final flag = (opt?.flagEmoji.isNotEmpty == true) ? opt!.flagEmoji : '🌍';
    final radius = BorderRadius.circular(14.dp);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          padding: EdgeInsets.symmetric(horizontal: 8.dp, vertical: 6.dp),
          decoration: BoxDecoration(
            color: selected ? c.accent : c.surface,
            borderRadius: radius,
            border: Border.all(
              color: selected ? c.accent : c.surfaceBorder,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(flag, style: TextStyle(fontSize: 16.sp)),
              Text(
                '${country.manufacturerCount}',
                style: TextStyle(
                  color: selected ? c.onAccent : c.textPrimary,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountrySheet extends StatelessWidget {
  final MarketMapCountry country;
  final VoidCallback onClose;
  final VoidCallback onViewProducts;
  final void Function(int userId) onOpenCompany;

  const _CountrySheet({
    required this.country,
    required this.onClose,
    required this.onViewProducts,
    required this.onOpenCompany,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final countries = Get.find<CountriesService>();
    final opt = countries.findByCode(country.country);
    final name = countries.displayName(country.country);
    final flag = (opt?.flagEmoji.isNotEmpty == true) ? opt!.flagEmoji : '🌍';
    final title = name.isNotEmpty ? '$flag $name' : '$flag ${country.country}';

    return Material(
      color: c.surface,
      elevation: 8,
      borderRadius: BorderRadius.circular(20.dp),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.dp, 14.dp, 12.dp, 16.dp),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: Icon(Icons.close_rounded, color: c.textSecondary),
                ),
              ],
            ),
            Text(
              'products_map_country_stats'.trParams({
                'm': '${country.manufacturerCount}',
                'p': '${country.productCount}',
              }),
              style: TextStyle(color: c.textSecondary, fontSize: 13.sp),
            ),
            if (country.companies.isNotEmpty) ...[
              SizedBox(height: 12.dp),
              Text(
                'products_map_companies'.tr,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6.dp),
              ...country.companies.take(5).map(
                (co) => Padding(
                  padding: EdgeInsets.only(bottom: 4.dp),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onOpenCompany(co.id),
                      borderRadius: BorderRadius.circular(10.dp),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 4.dp,
                          vertical: 8.dp,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                co.companyName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: c.textPrimary,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (co.verified || co.factoryVerified)
                              Icon(
                                Icons.verified_rounded,
                                size: 16.dp,
                                color: c.accent,
                              ),
                            SizedBox(width: 6.dp),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: c.textFaint,
                              size: 20.dp,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            SizedBox(height: 10.dp),
            PrimaryButton(
              text: 'products_map_view_products'.tr,
              onTap: onViewProducts,
            ),
          ],
        ),
      ),
    );
  }
}
