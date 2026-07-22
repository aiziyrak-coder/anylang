import 'package:get/get.dart';

import '../../../data/core/mappers.dart';
import '../../../data/network/products_repository.dart';
import '../../../data/network/profile_repository.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../add_product/add_product_screen.dart';
import '../edit_business_info/edit_business_info_screen.dart';
import '../products/product.dart';
import '../products/product_info_bottom_sheet.dart';
import '../profile_edit/profile_edit_screen.dart';
import '../settings/settings_screen.dart';
import '../subscription/subscription_screen.dart';
import 'profile_account.dart';
import 'profile_action.dart';
import 'profile_content.dart';
import 'profile_state.dart';

class ProfileScreen extends Screen<ProfileState, void> {
  ProfileScreen() : super(mobileContent: ProfileContent());

  @override
  void initState(void payload) {
    _load();
  }

  Future<void> _load() async {
    final result = await Get.find<ProfileRepository>().getMe();
    result.when(
      success: (data) {
        final map = asMap(data);
        if (map == null) return;
        state.account.value = ProfileAccount.fromApi(map);
      },
      failure: showAppError,
    );
    await _loadListings();
  }

  Future<void> _loadListings() async {
    final acc = state.account.value;
    if (acc == null || !acc.isBusiness) return;
    final result = await Get.find<ProductsRepository>().listMine(limit: 20);
    final data = result.dataOrNull;
    if (data == null) return;
    final items = asList(data)
        .whereType<Map>()
        .map((e) => Product.fromApi(Map<String, dynamic>.from(e)))
        .map(
          (p) => OwnListing(
            id: p.id,
            tileGradient: productGradientFor(p.id),
            name: p.name,
            price: p.price,
          ),
        )
        .toList();
    final current = state.account.value;
    if (current == null) return;
    state.account.value = current.copyWith(
      listings: items,
      listingsCount: items.length,
    );
  }

  @override
  Future<void> actionHandler(ProfileState state, MyAction action) async {
    switch (action) {
      case OpenSubscription _:
        await navigate(SubscriptionScreen());
        await _load();
      case OpenSettings _:
        await navigate(SettingsScreen());
        await _load();
      case EditPersonalProfile _:
        await navigate(ProfileEditScreen(), payload: state.account.value);
        await _load();
      case EditBusinessInfo _:
        await navigate(EditBusinessInfoScreen());
        await _load();
      case AddProductRequested _:
        await navigate(AddProductScreen());
        await _load();
      case SeeAllListings _:
        await _loadListings();
        final n = state.account.value?.listings.length ?? 0;
        showAppMessage(n == 0 ? 'Hali e’lon yo‘q' : '$n ta e’lon yangilandi');
      case OpenOwnListing a:
        final id = a.listing.id;
        if (id <= 0) {
          showAppMessage(a.listing.name);
          return;
        }
        final result = await Get.find<ProductsRepository>().detail(id);
        final map = asMap(result.dataOrNull);
        if (map == null) {
          showAppError(result.errorOrNull ?? 'Mahsulot topilmadi');
          return;
        }
        final product = Product.fromApi(map);
        await showProductInfoBottomSheet(
          context,
          product,
          onOpenBusiness: () {},
        );
        await _loadListings();
    }
  }
}
