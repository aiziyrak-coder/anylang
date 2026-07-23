import 'package:flutter/material.dart';
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
import '../settings/settings_payload.dart';
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
        await navigate(
          SettingsScreen(),
          payload: const SettingsPayload(focus: SettingsFocus.app),
        );
        await _load();
      case OpenAppSettings _:
        await navigate(
          SettingsScreen(),
          payload: const SettingsPayload(focus: SettingsFocus.app),
        );
        await _load();
      case OpenAccountSettings _:
        await navigate(
          SettingsScreen(),
          payload: const SettingsPayload(focus: SettingsFocus.account),
        );
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
        final items = state.account.value?.listings ?? const [];
        if (items.isEmpty) {
          showAppMessage('profile_listings_empty'.tr);
          return;
        }
        if (!context.mounted) return;
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              maxChildSize: 0.92,
              minChildSize: 0.4,
              builder: (_, scroll) => Container(
                decoration: BoxDecoration(
                  color: Theme.of(ctx).scaffoldBackgroundColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: ListView.separated(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: items.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      return Text(
                        'profile_listings_see_all'.tr,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    }
                    final listing = items[i - 1];
                    return ListTile(
                      title: Text(listing.name),
                      subtitle: Text(listing.price),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await actionHandler(state, OpenOwnListing(listing));
                      },
                    );
                  },
                ),
              ),
            );
          },
        );
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
          onOpenBusiness: () async {
            Navigator.of(context).maybePop();
            await navigate(EditBusinessInfoScreen());
            await _load();
          },
        );
        await _loadListings();
    }
  }
}
