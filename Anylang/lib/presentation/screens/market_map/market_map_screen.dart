import 'package:get/get.dart';

import '../../../data/core/mappers.dart';
import '../../../data/network/products_repository.dart';
import '../../../data/network/profile_repository.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/auth_validators.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../user_profile/user_profile_payload.dart';
import '../user_profile/user_profile_screen.dart';
import 'market_map_action.dart';
import 'market_map_content.dart';
import 'market_map_country.dart';
import 'market_map_state.dart';

class MarketMapScreen extends Screen<MarketMapState, void> {
  MarketMapScreen() : super(mobileContent: MarketMapContent());

  @override
  void initState(void payload) {
    _load();
  }

  Future<void> _load() async {
    state.loading.value = true;
    state.loadError.value = null;
    try {
      final result = await Get.find<ProductsRepository>().manufacturersMap();
      result.when(
        success: (data) {
          final map = asMap(data);
          final raw = map?['items'];
          final items = <MarketMapCountry>[];
          if (raw is List) {
            for (final e in raw) {
              if (e is Map) {
                items.add(
                  MarketMapCountry.fromApi(Map<String, dynamic>.from(e)),
                );
              }
            }
          }
          state.countries.assignAll(items);
          final serverTotal = (map?['total_manufacturers'] as num?)?.toInt();
          state.totalManufacturers.value = serverTotal ??
              items.fold<int>(0, (s, e) => s + e.manufacturerCount);
        },
        failure: (err) {
          state.countries.clear();
          state.selected.value = null;
          state.totalManufacturers.value = 0;
          state.loadError.value = AuthValidators.safeError(
            err,
            fallbackKey: 'products_map_load_failed',
          );
          showAppError(state.loadError.value);
        },
      );
    } finally {
      state.loading.value = false;
    }
  }

  Future<void> _openCompany(int userId) async {
    if (userId <= 0) return;
    final profile =
        await Get.find<ProfileRepository>().getPublicUser(userId);
    final map = asMap(profile.dataOrNull);
    if (map == null) {
      showAppError(profile.errorOrNull ?? 'error'.tr);
      return;
    }
    await navigate(
      UserProfileScreen(),
      payload: UserProfilePayload.fromApi(map),
    );
  }

  @override
  Future<void> actionHandler(
    MarketMapState state,
    MyAction action,
  ) async {
    switch (action) {
      case Back _:
        popBackNavigate();
      case MarketMapRefresh _:
        await _load();
      case MarketMapSelectCountry a:
        state.selected.value = a.country;
      case MarketMapViewProducts a:
        final code = a.countryCode.trim().toUpperCase();
        if (code.length != 2) {
          showAppError('products_map_invalid_country'.tr);
          return;
        }
        popBackNavigateWithResult(code);
      case MarketMapOpenCompany a:
        await _openCompany(a.userId);
    }
  }
}
