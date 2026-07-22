import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../ui/app_empty_state.dart';
import '../../ui/app_loading.dart';
import '../../ui/items/product_grid_card.dart';
import '../../ui/items/product_top_card.dart';
import '../../ui/search_field.dart';
import '../../ui/theme/colors.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import 'product.dart';
import 'products_action.dart';
import 'products_state.dart';

class ProductsContent extends ScreenContent<ProductsState> {

  // Asosiy ekran body'si ichida ochiladi — fon shaffof, tema gradienti ko'rinadi.
  ProductsContent() : super(color: Colors.transparent);

  @override
  Widget build(BuildContext context, ProductsState state, void Function(MyAction action) sendAction) {
    final c = context.appColors;

    return Padding(
      padding: EdgeInsets.only(top: 8.dp),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.dp),
            child: Text(
              'products_title'.tr,
              style: TextStyle(color: c.textPrimary, fontSize: 27.sp, fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(height: 16.dp),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.dp),
            child: SearchField(
              hint: 'products_search_hint'.tr,
              onChanged: (v) => sendAction(ProductsSearchChanged(v)),
            ),
          ),
          SizedBox(height: 18.dp),
          Expanded(
            child: Obx(() {
              if (state.loading.value || state.searching.value) {
                return const AppLoading();
              }
              final q = state.query.value.trim().toLowerCase();
              final searching = q.isNotEmpty;
              bool match(Product p) =>
                  p.name.toLowerCase().contains(q) ||
                  (p.subtitle?.toLowerCase().contains(q) ?? false);
              final all = searching ? state.all.where(match).toList() : state.all.toList();

              if (all.isEmpty && (searching || state.top.isEmpty)) {
                return AppEmptyState(
                  icon: searching ? Icons.search_off_rounded : Icons.storefront_outlined,
                  title: searching ? 'empty_no_results'.tr : 'products_empty'.tr,
                );
              }

              return RefreshIndicator(
                onRefresh: () async => sendAction(RefreshProducts()),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!searching) ...[
                      _sectionRow(c, state, sendAction),
                      SizedBox(height: 12.dp),
                      SizedBox(
                        height: 200.dp,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: EdgeInsets.symmetric(horizontal: 20.dp),
                          itemCount: state.top.length,
                          separatorBuilder: (_, _) => SizedBox(width: 12.dp),
                          itemBuilder: (_, i) {
                            final p = state.top[i];
                            return ProductTopCard(
                              iconAsset: p.iconAsset,
                              tileGradient: p.tileGradient,
                              name: p.name,
                              price: p.price,
                              views: p.views,
                              onTap: () => sendAction(OpenProduct(p)),
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 22.dp),
                    ],
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.dp),
                      child: Text(
                        (searching ? 'products_results' : 'products_all').tr,
                        style: TextStyle(color: c.textPrimary, fontSize: 15.sp, fontWeight: FontWeight.w700),
                      ),
                    ),
                    SizedBox(height: 12.dp),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(16.dp, 0, 16.dp, 16.dp),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12.dp,
                        mainAxisSpacing: 12.dp,
                        childAspectRatio: 0.9,
                      ),
                      itemCount: all.length,
                      itemBuilder: (_, i) {
                        final p = all[i];
                        return ProductGridCard(
                          iconAsset: p.iconAsset,
                          tileGradient: p.tileGradient,
                          name: p.name,
                          subtitle: p.subtitle,
                          price: p.price,
                          views: p.views,
                          imageUrl: p.imageUrl,
                          onTap: () => sendAction(OpenProduct(p)),
                        );
                      },
                    ),
                  ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _sectionRow(AppColors c, ProductsState state, void Function(MyAction) sendAction) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.dp),
      child: Row(
        children: [
          Icon(Icons.star_rounded, color: c.accent, size: 18.dp),
          SizedBox(width: 6.dp),
          Text(
            'products_top'.tr,
            style: TextStyle(color: c.textPrimary, fontSize: 15.sp, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                sendAction(ProductsSearchChanged(''));
              },
              borderRadius: BorderRadius.circular(8.dp),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.dp, vertical: 2.dp),
                child: Text(
                  'products_see_all'.tr,
                  style: TextStyle(color: c.textFaint, fontSize: 13.sp),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
