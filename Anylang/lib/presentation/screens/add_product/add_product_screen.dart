import 'package:flutter/material.dart';
import '../../modal/image_picker.dart';
import '../../ui/theme/gradients.dart';
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

class AddProductScreen extends Screen<AddProductState, void> {

  AddProductScreen() : super(
    mobileContent: AddProductContent(),
  );

  @override
  void initState(void payload) {
    // TODO: tahrirlash rejimida mavjud mahsulot ma'lumotini yuklash.
    state.images.addAll([
      const ProductImageDraft(gradient: prodTealGradient, isPrimary: true),
      const ProductImageDraft(gradient: prodBrownGradient),
    ]);
  }

  @override
  Future<void> actionHandler(AddProductState state, MyAction action) async {
    switch (action) {
      case Back _:
        popBackNavigate();
      case AddProductImageRequested _:
        final file = await pickImage(context);
        if (file != null) {
          final gradient = _kImageGradientPool[state.images.length % _kImageGradientPool.length];
          state.images.add(ProductImageDraft(gradient: gradient, isPrimary: state.images.isEmpty));
        }
      case RemoveProductImage a:
        final removedWasPrimary = state.images[a.index].isPrimary;
        state.images.removeAt(a.index);
        if (removedWasPrimary && state.images.isNotEmpty) {
          final first = state.images.first;
          state.images[0] = ProductImageDraft(gradient: first.gradient, isPrimary: true);
        }
      case SelectCurrency a:
        state.currency.value = a.currency;
      case SelectCategory a:
        state.category.value = a.category;
      case SaveDraftRequested _:
        // TODO: qoralama sifatida saqlash so'rovi.
        popBackNavigate();
      case PublishProductRequested _:
        state.isSubmitting.value = true;
        // TODO: haqiqiy e'lon qilish so'rovi.
        state.isSubmitting.value = false;
        popBackNavigate();
    }
  }
}
