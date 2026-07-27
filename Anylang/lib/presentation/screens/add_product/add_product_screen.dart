import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/core/mappers.dart';
import '../../../data/network/products_repository.dart';
import '../../modal/country_picker_bottom_sheet.dart';
import '../../modal/image_picker.dart';
import '../../modal/video_picker.dart';
import '../../ui/theme/gradients.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/auth_validators.dart';
import '../../utils/business_plan_dialog.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../subscription/subscription_screen.dart';
import 'add_product_action.dart';
import 'add_product_content.dart';
import 'add_product_payload.dart';
import 'add_product_state.dart';
import 'product_image_draft.dart';

const List<LinearGradient> _kImageGradientPool = [
  prodTealGradient,
  prodBrownGradient,
  prodPurpleGradient,
  prodBlueGradient,
  prodOliveGradient,
  prodMaroonGradient,
];

const Map<String, String> _kCategoryCodes = {
  'add_product_cat_clothing': 'clothing_accessories',
  'add_product_cat_pottery': 'pottery',
  'add_product_cat_wood': 'woodwork',
  'add_product_cat_jewelry': 'jewelry',
  'add_product_cat_other': 'other',
};

class AddProductScreen extends Screen<AddProductState, AddProductPayload?> {
  AddProductScreen() : super(mobileContent: AddProductContent());

  @override
  void initState(AddProductPayload? payload) {
    state.images.clear();
    state.shippingCountries.clear();
    state.productVideoUrl.value = null;
    state.videoUploading.value = false;
    state.category.value = kProductCategoryKeys.first;
    state.editingProductId.value = payload?.editProductId;
    final editId = payload?.editProductId;
    if (editId != null && editId > 0) {
      unawaited(_hydrateForEdit(editId));
    }
  }

  Future<void> _hydrateForEdit(int productId) async {
    final result = await Get.find<ProductsRepository>().detail(productId);
    final map = asMap(result.dataOrNull);
    if (map == null) {
      showAppError(result.errorOrNull ?? 'product_not_found'.tr);
      return;
    }
    state.draftName.value = map['name']?.toString() ?? '';
    state.draftPrice.value = map['price']?.toString() ?? '';
    state.draftShort.value = map['short_description']?.toString() ?? '';
    state.draftDetailed.value = map['description']?.toString() ?? '';
    state.draftMoq.value = map['moq']?.toString() ?? '';
    state.draftShipping.value = map['shipping_info']?.toString() ?? '';
    state.draftFactoryVideo.value = map['factory_video_url']?.toString() ?? '';
    state.draftProcessVideo.value = map['process_video_url']?.toString() ?? '';
    final video = map['video_url']?.toString();
    state.productVideoUrl.value =
        (video != null && video.isNotEmpty) ? video : null;
    final currency = map['currency']?.toString();
    if (currency != null && currency.isNotEmpty) {
      state.currency.value = currency;
    }
    final catCode = map['category']?.toString() ?? 'other';
    final catKey = _kCategoryCodes.entries
        .firstWhere(
          (e) => e.value == catCode,
          orElse: () => const MapEntry('add_product_cat_other', 'other'),
        )
        .key;
    state.category.value = catKey;
    state.shippingCountries.assignAll(
      (map['shipping_countries'] is List)
          ? (map['shipping_countries'] as List)
              .map((e) => e.toString().toUpperCase())
              .where((e) => e.isNotEmpty)
              .toList()
          : const <String>[],
    );
    final images = <ProductImageDraft>[];
    final rawImages = map['images'];
    if (rawImages is List) {
      for (var i = 0; i < rawImages.length; i++) {
        final item = rawImages[i];
        if (item is! Map) continue;
        final id = (item['id'] as num?)?.toInt();
        final url = item['url']?.toString();
        if (id == null || url == null || url.isEmpty) continue;
        images.add(
          ProductImageDraft(
            gradient: _kImageGradientPool[i % _kImageGradientPool.length],
            isPrimary: item['is_primary'] == true || i == 0,
            imageId: id,
            imageUrl: url,
          ),
        );
      }
    }
    state.images.assignAll(images);
    state.draftHydrateToken.value++;
  }

  @override
  void dispose() {
    state.videoUploading.value = false;
    super.dispose();
  }

  @override
  Future<void> actionHandler(AddProductState state, MyAction action) async {
    switch (action) {
      case Back _:
        popBackNavigate();
      case AddProductImageRequested _:
        final file = await pickImage(context);
        if (file != null) {
          final gradient =
              _kImageGradientPool[state.images.length % _kImageGradientPool.length];
          state.images.add(
            ProductImageDraft(
              gradient: gradient,
              isPrimary: state.images.isEmpty,
              filePath: file.path,
            ),
          );
        }
      case RemoveProductImage a:
        if (a.index < 0 || a.index >= state.images.length) return;
        final removedWasPrimary = state.images[a.index].isPrimary;
        state.images.removeAt(a.index);
        if (removedWasPrimary && state.images.isNotEmpty) {
          final first = state.images.first;
          state.images[0] = ProductImageDraft(
            gradient: first.gradient,
            isPrimary: true,
            filePath: first.filePath,
            imageId: first.imageId,
            imageUrl: first.imageUrl,
          );
        }
      case SelectCurrency a:
        state.currency.value = a.currency;
      case SelectCategory a:
        state.category.value = a.category;
      case AddShippingCountryRequested _:
        final picked = await showCountryPickerBottomSheet(
          context,
          title: 'product_shipping_countries'.tr,
          desc: 'business_add_export_country'.tr,
        );
        if (picked == null) return;
        final code = picked.code.toUpperCase();
        if (!state.shippingCountries.contains(code)) {
          state.shippingCountries.add(code);
        }
      case RemoveShippingCountry a:
        state.shippingCountries.remove(a.code);
      case PickProductVideoRequested _:
        if (state.videoUploading.value) return;
        final file = await pickProductVideo(context);
        if (file == null) return;
        state.videoUploading.value = true;
        try {
          final up =
              await Get.find<ProductsRepository>().uploadVideo(file.path);
          final map = asMap(up.dataOrNull);
          final url = (map?['url'] as String?)?.trim();
          if (url == null || url.isEmpty) {
            showAppError(AuthValidators.safeError(
              up.errorOrNull,
              fallbackKey: 'product_video_upload_failed',
            ));
            return;
          }
          state.productVideoUrl.value = url;
          showAppMessage('product_video_uploaded'.tr);
        } finally {
          state.videoUploading.value = false;
        }
      case ClearProductVideoRequested _:
        state.productVideoUrl.value = null;
      case SaveDraftRequested a:
        await _submit(
          state,
          name: a.name,
          price: a.price,
          shortDescription: a.shortDescription,
          detailedDescription: a.detailedDescription,
          moq: a.moq,
          shippingInfo: a.shippingInfo,
          videoUrl: (state.productVideoUrl.value ?? a.videoUrl).trim(),
          factoryVideoUrl: a.factoryVideoUrl,
          processVideoUrl: a.processVideoUrl,
          status: 'draft',
        );
      case PublishProductRequested a:
        await _submit(
          state,
          name: a.name,
          price: a.price,
          shortDescription: a.shortDescription,
          detailedDescription: a.detailedDescription,
          moq: a.moq,
          shippingInfo: a.shippingInfo,
          videoUrl: (state.productVideoUrl.value ?? a.videoUrl).trim(),
          factoryVideoUrl: a.factoryVideoUrl,
          processVideoUrl: a.processVideoUrl,
          status: 'published',
        );
    }
  }

  Future<void> _submit(
    AddProductState state, {
    required String name,
    required String price,
    required String shortDescription,
    required String detailedDescription,
    required String moq,
    required String shippingInfo,
    required String videoUrl,
    required String factoryVideoUrl,
    required String processVideoUrl,
    required String status,
  }) async {
    if (state.isSubmitting.value || state.videoUploading.value) {
      if (state.videoUploading.value) {
        showAppWarning('product_video_uploading'.tr);
      }
      return;
    }
    name = name.trim();
    price = price.trim().replaceAll(',', '.');
    shortDescription = shortDescription.trim();
    detailedDescription = detailedDescription.trim();
    moq = moq.trim();
    shippingInfo = shippingInfo.trim();
    videoUrl = videoUrl.trim();
    factoryVideoUrl = factoryVideoUrl.trim();
    processVideoUrl = processVideoUrl.trim();

    if (name.length < 2) {
      showAppError('add_product_name_required'.tr);
      return;
    }
    if (price.isEmpty || double.tryParse(price) == null) {
      showAppError('add_product_price_invalid'.tr);
      return;
    }
    final parsedPrice = double.parse(price);
    if (parsedPrice <= 0) {
      showAppError('add_product_price_invalid'.tr);
      return;
    }
    if (state.videoUploading.value) {
      showAppWarning('product_video_uploading'.tr);
      return;
    }
    final paths = state.images
        .map((e) => e.filePath)
        .whereType<String>()
        .where((p) => p.isNotEmpty && File(p).existsSync())
        .toList();
    final existingIds = state.images
        .where((e) => !e.hasLocalFile && (e.imageId ?? 0) > 0)
        .map((e) => e.imageId!)
        .toList();
    if (paths.isEmpty && existingIds.isEmpty && status == 'published') {
      showAppError('add_product_image_required'.tr);
      return;
    }
    if (paths.isEmpty && existingIds.isEmpty && status == 'draft') {
      showAppMessage('add_product_draft_no_image_hint'.tr);
    }

    state.isSubmitting.value = true;
    try {
      final repo = Get.find<ProductsRepository>();
      final imageIds = <int>[...existingIds];
      for (final path in paths) {
        final up = await repo.uploadImage(path);
        final map = asMap(up.dataOrNull);
        final id = (map?['id'] as num?)?.toInt();
        if (id == null) {
          showAppError(AuthValidators.safeError(
            up.errorOrNull,
            fallbackKey: 'add_product_image_upload_failed',
          ));
          return;
        }
        imageIds.add(id);
      }
      final cat = _kCategoryCodes[state.category.value] ?? 'other';
      final short = shortDescription.isNotEmpty ? shortDescription : name;
      final detailed =
          detailedDescription.isEmpty ? short : detailedDescription;
      final body = <String, dynamic>{
        'name': name,
        'short_description': short,
        'description': detailed,
        'price': price,
        'currency': state.currency.value,
        'category': cat,
        if (imageIds.isNotEmpty) 'image_ids': imageIds,
        if (imageIds.isNotEmpty) 'primary_image_id': imageIds.first,
        'status': status,
        'shipping_countries': state.shippingCountries.toList(),
        // Imkoniyatlar olib tashlandi — eski qiymatlarni tozalash.
        'capabilities': <String>[],
      };
      if (moq.isNotEmpty) body['moq'] = moq;
      if (shippingInfo.isNotEmpty) body['shipping_info'] = shippingInfo;
      if (videoUrl.isNotEmpty) body['video_url'] = videoUrl;
      if (factoryVideoUrl.isNotEmpty) body['factory_video_url'] = factoryVideoUrl;
      if (processVideoUrl.isNotEmpty) body['process_video_url'] = processVideoUrl;

      final editId = state.editingProductId.value;
      final result = (editId != null && editId > 0)
          ? await repo.update(editId, body)
          : await repo.create(body);
      if (result.dataOrNull != null) {
        showAppMessage(
          status == 'draft'
              ? 'add_product_draft_saved'.tr
              : (editId != null && editId > 0)
                  ? 'edit_product_saved'.tr
                  : 'add_product_published'.tr,
        );
        popBackNavigate();
        return;
      }
      final errCode = AuthValidators.apiErrorCode(result.errorOrNull);
      if (errCode == 'NOT_A_BUSINESS') {
        showAppError('add_product_business_required'.tr);
        final goPlans = await showBusinessPlanRequiredDialog();
        if (goPlans) {
          await navigate(SubscriptionScreen());
        }
      } else {
        showAppError(AuthValidators.safeError(result.errorOrNull));
      }
    } finally {
      state.isSubmitting.value = false;
    }
  }
}
