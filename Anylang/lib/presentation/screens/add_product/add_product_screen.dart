import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/core/mappers.dart';
import '../../../data/network/products_repository.dart';
import '../../modal/image_picker.dart';
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
      case SaveDraftRequested a:
        await _submit(
          state,
          name: a.name,
          price: a.price,
          shortDescription: a.shortDescription,
          detailedDescription: a.detailedDescription,
          status: 'draft',
        );
      case PublishProductRequested a:
        await _submit(
          state,
          name: a.name,
          price: a.price,
          shortDescription: a.shortDescription,
          detailedDescription: a.detailedDescription,
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
    required String status,
  }) async {
    name = name.trim();
    price = price.trim().replaceAll(',', '.');
    shortDescription = shortDescription.trim();
    detailedDescription = detailedDescription.trim();

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
      final result = await repo.create({
        'name': name,
        'short_description': shortDescription,
        'description': detailedDescription.isEmpty
            ? shortDescription
            : detailedDescription,
        'price': price,
        'currency': state.currency.value,
        'category': cat,
        'image_ids': imageIds,
        'primary_image_id': imageIds.first,
        'status': status,
      });
      if (result.dataOrNull != null) {
        showAppMessage(
          status == 'draft'
              ? 'add_product_draft_saved'.tr
              : 'add_product_published'.tr,
        );
        popBackNavigate();
        return;
      }
      final err = result.errorOrNull?.toString() ?? '';
      if (err.contains('NOT_A_BUSINESS') || err.contains('business')) {
        showAppError('add_product_business_required'.tr);
      } else {
        showAppError(result.errorOrNull ?? 'error'.tr);
      }
    } finally {
      state.isSubmitting.value = false;
    }
  }
}
