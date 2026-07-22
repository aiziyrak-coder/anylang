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
  'Kiyim & aksessuar': 'clothing_accessories',
  'Kulolchilik': 'pottery',
  "Yog‘och buyumlar": 'woodwork',
  'Taqinchoq': 'jewelry',
  'Boshqa': 'other',
};

class AddProductScreen extends Screen<AddProductState, void> {
  AddProductScreen() : super(mobileContent: AddProductContent());

  @override
  void initState(void payload) {
    state.images.clear();
    state.category.value = kProductCategories.first;
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
      case SaveDraftRequested _:
        showAppMessage('Qoralama saqlandi (faqat qurilmada)');
        popBackNavigate();
      case PublishProductRequested a:
        await _publish(state, a);
    }
  }

  Future<void> _publish(
    AddProductState state,
    PublishProductRequested a,
  ) async {
    final name = a.name.trim();
    final price = a.price.trim().replaceAll(',', '.');
    if (name.length < 2) {
      showAppError('Mahsulot nomi kerak');
      return;
    }
    if (price.isEmpty || double.tryParse(price) == null) {
      showAppError('Narx noto‘g‘ri');
      return;
    }
    final paths = state.images
        .map((e) => e.filePath)
        .whereType<String>()
        .where((p) => p.isNotEmpty && File(p).existsSync())
        .toList();
    if (paths.isEmpty) {
      showAppError('Kamida 1 ta rasm qo‘shing');
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
          showAppError(up.errorOrNull ?? 'Rasm yuklanmadi');
          return;
        }
        imageIds.add(id);
      }
      final cat = _kCategoryCodes[state.category.value] ?? 'other';
      final result = await repo.create({
        'name': name,
        'short_description': a.shortDescription.trim(),
        'description': a.detailedDescription.trim().isEmpty
            ? a.shortDescription.trim()
            : a.detailedDescription.trim(),
        'price': price,
        'currency': state.currency.value,
        'category': cat,
        'image_ids': imageIds,
        'primary_image_id': imageIds.first,
        'status': 'published',
      });
      if (result.dataOrNull != null) {
        showAppMessage('Mahsulot e’lon qilindi');
        popBackNavigate();
      } else {
        showAppError(result.errorOrNull ?? 'error'.tr);
      }
    } finally {
      state.isSubmitting.value = false;
    }
  }
}
