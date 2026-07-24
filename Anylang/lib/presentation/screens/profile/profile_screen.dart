import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/core/mappers.dart';
import '../../../data/local/session_store.dart';
import '../../../data/network/products_repository.dart';
import '../../../data/network/profile_repository.dart';
import '../../modal/full_screen_image_dialog.dart';
import '../../ui/theme/colors.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../../utils/size_controller.dart';
import '../add_product/add_product_screen.dart';
import '../edit_business_info/edit_business_info_screen.dart';
import '../products/product.dart';
import '../products/product_info_bottom_sheet.dart';
import '../profile_edit/profile_edit_screen.dart';
import '../settings/settings_payload.dart';
import '../settings/settings_screen.dart';
import '../subscription/subscription_screen.dart';
import '../numbers/numbers_screen.dart';
import '../support_chat/support_chat_screen.dart';
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
    state.loading.value = true;
    state.error.value = null;
    final result = await Get.find<ProfileRepository>().getMe();
    result.when(
      success: (data) {
        final map = asMap(data);
        if (map == null) {
          state.error.value = 'profile_load_failed'.tr;
          state.loading.value = false;
          return;
        }
        state.account.value = ProfileAccount.fromApi(map);
        state.error.value = null;
        unawaited(SessionStore.saveUser(Map<String, dynamic>.from(map)));
      },
      failure: (err) {
        state.error.value = err.toString();
        showAppError(err);
      },
    );
    state.loading.value = false;
    await _loadListings();
  }

  Future<void> _loadListings() async {
    final acc = state.account.value;
    if (acc == null || !acc.isBusiness) return;
    final result = await Get.find<ProductsRepository>().listMine(limit: 40);
    if (result.errorOrNull != null) {
      showAppError(result.errorOrNull);
      return;
    }
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
            imageUrl: p.imageUrl,
            status: p.status,
            isTop: p.isTop,
            topRequestStatus: p.topRequestStatus,
          ),
        )
        .toList();
    final current = state.account.value;
    if (current == null) return;
    // API stats.listings_count saqlanadi — faqat ro'yxat yangilanadi.
    state.account.value = current.copyWith(listings: items);
  }

  @override
  Future<void> actionHandler(ProfileState state, MyAction action) async {
    switch (action) {
      case OpenSubscription _:
        await navigate(SubscriptionScreen());
        await _load();
      case OpenNumbers _:
        await navigate(NumbersScreen());
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
      case OpenSupportFromProfile _:
        await navigate(SupportChatScreen());
      case OpenAccountSettings _:
        // Akkaunt sozlamalari olib tashlandi — tizim sozlamalariga yo'naltiriladi.
        await navigate(
          SettingsScreen(),
          payload: const SettingsPayload(focus: SettingsFocus.app),
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
      case RetryProfileLoad _:
        await _load();
      case OpenProfileAvatar _:
        final url = state.account.value?.avatarUrl?.trim();
        if (url == null || url.isEmpty) return;
        await showFullScreenImage(context, url: url);
      case SeeAllListings _:
        await _loadListings();
        final items = state.account.value?.listings ?? const [];
        if (items.isEmpty) {
          showAppMessage('profile_listings_empty'.tr);
          return;
        }
        if (!context.mounted) return;
        final c = context.appColors;
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
                  color: c.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20.dp)),
                ),
                child: ListView.separated(
                  controller: scroll,
                  padding: EdgeInsets.fromLTRB(16.dp, 16.dp, 16.dp, 24.dp),
                  itemCount: items.length + 1,
                  separatorBuilder: (_, _) => SizedBox(height: 8.dp),
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      return Text(
                        'profile_listings_see_all'.tr,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    }
                    final listing = items[i - 1];
                    final img = listing.imageUrl?.trim();
                    return Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(10.dp),
                          child: SizedBox(
                            width: 48.dp,
                            height: 48.dp,
                            child: img != null && img.isNotEmpty
                                ? Image.network(img, fit: BoxFit.cover)
                                : DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: listing.tileGradient,
                                    ),
                                  ),
                          ),
                        ),
                        title: Text(
                          listing.name,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          listing.price,
                          style: TextStyle(color: c.textSecondary),
                        ),
                        onTap: () async {
                          Navigator.pop(ctx);
                          await actionHandler(state, OpenOwnListing(listing));
                        },
                      ),
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
          showAppError(result.errorOrNull ?? 'product_not_found'.tr);
          return;
        }
        final product = Product.fromApi(map);
        if (!context.mounted) return;
        await showProductInfoBottomSheet(
          context,
          product,
          onOpenBusiness: () {
            // O'z mahsuloti — biznes sahifasiga o'tish shart emas.
            Navigator.of(context).maybePop();
          },
        );
        await _loadListings();
    }
  }
}
