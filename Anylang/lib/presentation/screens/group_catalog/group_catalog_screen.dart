import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/core/mappers.dart';
import '../../../data/network/chat_repository.dart';
import '../../../data/network/products_repository.dart';
import '../../../data/network/profile_repository.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../products/product.dart';
import '../products/product_info_bottom_sheet.dart';
import '../user_profile/user_profile_payload.dart';
import '../user_profile/user_profile_screen.dart';
import 'group_catalog_action.dart';
import 'group_catalog_content.dart';
import 'group_catalog_models.dart';
import 'group_catalog_payload.dart';
import 'group_catalog_state.dart';

class GroupCatalogScreen extends Screen<GroupCatalogState, GroupCatalogPayload> {
  GroupCatalogScreen() : super(mobileContent: GroupCatalogContent());

  @override
  void initState(GroupCatalogPayload? payload) {
    if (payload != null) {
      state.chatId.value = payload.chatId;
      state.title.value = payload.title;
      state.section.value = payload.initialSection;
    }
    _load();
  }

  Future<void> _load() async {
    final chatId = state.chatId.value;
    if (chatId <= 0) {
      state.loading.value = false;
      return;
    }
    state.loading.value = true;
    final result = await Get.find<ChatRepository>().groupCatalog(
      chatId,
      section: 'all',
    );
    state.loading.value = false;
    result.when(
      success: (data) {
        final map = asMap(data);
        if (map == null) return;
        final catalog = GroupCatalogData.fromApi(map);
        state.products.assignAll(catalog.products);
        state.documents.assignAll(catalog.documents);
        state.companies.assignAll(catalog.companies);
        state.counts
          ..clear()
          ..addAll(catalog.counts);
      },
      failure: showAppError,
    );
  }

  Future<void> _openProduct(GroupCatalogProduct item) async {
    final id = item.productId;
    if (id == null || id <= 0) {
      showAppMessage('group_catalog_product_no_detail'.tr);
      return;
    }
    final result = await Get.find<ProductsRepository>().detail(id);
    final map = asMap(result.dataOrNull);
    if (map == null) {
      showAppError(result.errorOrNull ?? 'error'.tr);
      return;
    }
    if (!context.mounted) return;
    final product = Product.fromApi(map);
    await showProductInfoBottomSheet(
      context,
      product,
      onOpenBusiness: () async {
        final sellerId = product.sellerId;
        if (sellerId <= 0) return;
        final profile =
            await Get.find<ProfileRepository>().getPublicUser(sellerId);
        final pmap = asMap(profile.dataOrNull);
        if (pmap == null) {
          showAppError(profile.errorOrNull ?? 'error'.tr);
          return;
        }
        await navigate(
          UserProfileScreen(),
          payload: UserProfilePayload.fromApi(pmap),
        );
      },
    );
  }

  Future<void> _openDocument(GroupCatalogDocument item) async {
    final url = (item.url ?? '').trim();
    if (url.isEmpty) {
      showAppMessage('group_catalog_document_no_url'.tr);
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      showAppMessage('group_catalog_document_no_url'.tr);
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) showAppError('error'.tr);
  }

  Future<void> _openCompany(GroupCatalogCompany item) async {
    if (item.userId <= 0) return;
    final profile =
        await Get.find<ProfileRepository>().getPublicUser(item.userId);
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
    GroupCatalogState state,
    MyAction action,
  ) async {
    switch (action) {
      case Back _:
        popBackNavigate();
      case GroupCatalogRefresh _:
        await _load();
      case GroupCatalogSelectSection a:
        state.section.value = a.section;
      case GroupCatalogOpenProduct a:
        await _openProduct(a.item);
      case GroupCatalogOpenDocument a:
        await _openDocument(a.item);
      case GroupCatalogOpenCompany a:
        await _openCompany(a.item);
    }
  }
}
