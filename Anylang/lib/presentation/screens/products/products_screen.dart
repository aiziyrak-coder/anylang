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

  ProductsScreen() : super(
    mobileContent: ProductsContent(),
  );

  @override
  void initState(void payload) {
    // TODO: mahsulotlarni backenddan yuklash. Hozircha mock.
    state.top.addAll(kMockTopProducts);
    state.all.addAll(kMockAllProducts);
  }

  @override
  Future<void> actionHandler(ProductsState state, MyAction action) async {
    switch (action) {
      case ProductsSearchChanged a:
        state.query.value = a.text;
      case OpenProduct a:
        showProductInfoBottomSheet(
          context,
          a.product,
          onOpenBusiness: () =>
              navigate(UserProfileScreen(), payload: kAnadoluBusinessProfile),
        );
    }
  }
}
