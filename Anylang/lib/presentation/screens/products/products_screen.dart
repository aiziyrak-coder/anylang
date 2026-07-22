import 'package:get/get.dart';

import '../../../data/core/mappers.dart';
import '../../../data/network/products_repository.dart';
import '../../../data/network/profile_repository.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../user_profile/user_profile_payload.dart';
import '../user_profile/user_profile_screen.dart';
import 'product.dart';
import 'product_info_bottom_sheet.dart';
import 'products_action.dart';
import 'products_content.dart';
import 'products_state.dart';

class ProductsScreen extends Screen<ProductsState, void> {
  ProductsScreen() : super(mobileContent: ProductsContent());

  @override
  void initState(void payload) {
    _load();
  }

  Future<void> _load() async {
    state.loading.value = true;
    state.top.clear();
    state.all.clear();
    final repo = Get.find<ProductsRepository>();
    final top = await repo.top();
    top.when(
      success: (data) {
        final items = asList(data)
            .whereType<Map>()
            .map((e) => Product.fromApi(Map<String, dynamic>.from(e)))
            .toList();
        state.top.assignAll(items);
      },
      failure: (_) {},
    );
    final all = await repo.list();
    all.when(
      success: (data) {
        final items = asList(data)
            .whereType<Map>()
            .map((e) => Product.fromApi(Map<String, dynamic>.from(e)))
            .toList();
        state.all.assignAll(items);
      },
      failure: showAppError,
    );
    state.loading.value = false;
  }

  @override
  Future<void> actionHandler(ProductsState state, MyAction action) async {
    switch (action) {
      case ProductsSearchChanged a:
        state.query.value = a.text;
        if (a.text.trim().isEmpty) {
          state.searching.value = false;
          await _load();
          return;
        }
        state.searching.value = true;
        final result = await Get.find<ProductsRepository>().list(q: a.text.trim());
        result.when(
          success: (data) {
            final items = asList(data)
                .whereType<Map>()
                .map((e) => Product.fromApi(Map<String, dynamic>.from(e)))
                .toList();
            state.all.assignAll(items);
          },
          failure: showAppError,
        );
        state.searching.value = false;
      case OpenProduct a:
        showProductInfoBottomSheet(
          context,
          a.product,
          onOpenBusiness: () async {
            if (a.product.sellerId <= 0) return;
            final result =
                await Get.find<ProfileRepository>().getPublicUser(a.product.sellerId);
            result.when(
              success: (data) {
                final map = asMap(data);
                if (map == null) return;
                navigate(
                  UserProfileScreen(),
                  payload: UserProfilePayload.fromApi(map),
                );
              },
              failure: showAppError,
            );
          },
        );
    }
  }
}
