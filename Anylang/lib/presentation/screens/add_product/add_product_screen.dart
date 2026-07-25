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
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import 'add_product_action.dart';
import 'add_product_content.dart';
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

class AddProductScreen extends Screen<AddProductState, void> {
  AddProductScreen() : super(mobileContent: AddProductContent());

  @override
  void initState(void payload) {
    state.images.clear();
    state.shippingCountries.clear();
    state.capabilities.clear();
    state.productVideoUrl.value = null;
    state.videoUploading.value = false;
    state.category.value = kProductCategoryKeys.first;
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
        final removedWasPrimary = state.images[a.index].isPrimary;
        state.images.removeAt(a.index);
        if (removedWasPrimary && state.images.isNotEmpty) {
          final first = state.images.first;
          state.images[0] = ProductImageDraft(
            gradient: first.gradient,
            isPrimary: true,
            filePath: first.filePath,
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
            showAppError(up.errorOrNull ?? 'product_video_upload_failed'.tr);
            return;
          }
          state.productVideoUrl.value = url;
          showAppMessage('product_video_uploaded'.tr);
        } finally {
          state.videoUploading.value = false;
        }
      case ClearProductVideoRequested _:
        state.productVideoUrl.value = null;
      case ToggleProductCapability a:
        if (state.capabilities.contains(a.code)) {
          state.capabilities.remove(a.code);
        } else if (state.capabilities.length < 8) {
          state.capabilities.add(a.code);
        }
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
    final paths = state.images
        .map((e) => e.filePath)
        .whereType<String>()
        .where((p) => p.isNotEmpty && File(p).existsSync())
        .toList();
    if (paths.isEmpty) {
      showAppError('add_product_image_required'.tr);
      return;
    }

    state.isSubmitting.value = true;
    try {
      final repo = Get.find<ProductsRepository>();
      final imageIds = <int>[];
      for (final path in paths) {
        final up = await repo.uploadImage(path);
        final map = asMap(up.dataOrNull);
        final id = (map?['id'] as num?)?.toInt();
        if (id == null) {
          showAppError(up.errorOrNull ?? 'add_product_image_upload_failed'.tr);
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
        'image_ids': imageIds,
        'primary_image_id': imageIds.first,
        'status': status,
        'shipping_countries': state.shippingCountries.toList(),
        'capabilities': state.capabilities.toList(),
      };
      if (moq.isNotEmpty) body['moq'] = moq;
      if (shippingInfo.isNotEmpty) body['shipping_info'] = shippingInfo;
      if (videoUrl.isNotEmpty) body['video_url'] = videoUrl;
      if (factoryVideoUrl.isNotEmpty) body['factory_video_url'] = factoryVideoUrl;
      if (processVideoUrl.isNotEmpty) body['process_video_url'] = processVideoUrl;
      final result = await repo.create(body);
      if (result.dataOrNull != null) {
        showAppMessage('action_done'.tr);
        popBackNavigate();
        return;
      }
      final err = result.errorOrNull?.toString() ?? '';
      if (err.contains('NOT_A_BUSINESS') ||
          err.toLowerCase().contains('biznes') ||
          err.toLowerCase().contains('business')) {
        showAppError('add_product_business_required'.tr);
      } else {
        showAppError(result.errorOrNull ?? 'error'.tr);
      }
    } finally {
      state.isSubmitting.value = false;
    }
  }
}
