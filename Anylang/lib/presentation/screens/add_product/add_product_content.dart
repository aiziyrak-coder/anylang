import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../modal/simple_list_picker_bottom_sheet.dart';
import '../../ui/app_top_bar.dart';
import '../../ui/buttons/primary_button.dart';
import '../../ui/buttons/secondary_button.dart';
import '../../ui/gradient_background.dart';
import '../../ui/keyboard_aware_scroll.dart';
import '../../ui/items/media_tile.dart';
import '../../ui/textfields/app_picker_field.dart';
import '../../ui/textfields/app_text_field.dart';
import '../../ui/theme/colors.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import 'add_product_action.dart';
import 'add_product_state.dart';

const List<String> kProductCurrencies = ['USD', 'EUR', 'RUB', 'UZS'];

const List<String> kProductCategoryKeys = [
  'add_product_cat_clothing',
  'add_product_cat_pottery',
  'add_product_cat_wood',
  'add_product_cat_jewelry',
  'add_product_cat_other',
];

/// S18 — Mahsulot qo'shish. Rasmlar, nom, narx/valyuta, kategoriya,
/// qisqa/batafsil tavsif + qoralama/e'lon qilish.
class AddProductContent extends ScreenContent<AddProductState> {

  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _shortDescCtrl;
  late final TextEditingController _detailedDescCtrl;

  @override
  void initContent() {
    _nameCtrl = TextEditingController();
    _priceCtrl = TextEditingController();
    _shortDescCtrl = TextEditingController();
    _detailedDescCtrl = TextEditingController();
  }

  @override
  void onClose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _shortDescCtrl.dispose();
    _detailedDescCtrl.dispose();
  }

  @override
  Widget build(BuildContext context, AddProductState state, void Function(MyAction action) sendAction) {
    final c = context.appColors;

    return GradientBackground(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.dp, 4.dp, 16.dp, 0),
              child: AppTopBar(
                title: 'add_product_title'.tr,
                leadingIcon: Icons.close_rounded,
                onBack: () => sendAction(Back()),
              ),
            ),
            Expanded(
              child: KeyboardAwareScrollView(
                padding: EdgeInsets.fromLTRB(20.dp, 16.dp, 20.dp, 24.dp),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'add_product_images'.tr,
                      style: TextStyle(color: c.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 10.dp),
                    Obx(() => Wrap(
                          spacing: 10.dp,
                          runSpacing: 10.dp,
                          children: [
                            MediaTile.upload(
                              uploadLabel: 'business_upload'.tr,
                              onTap: () => sendAction(AddProductImageRequested()),
                            ),
                            for (var i = 0; i < state.images.length; i++)
                              MediaTile.image(
                                gradient: state.images[i].gradient,
                                onRemove: () => sendAction(RemoveProductImage(i)),
                                badgeText: state.images[i].isPrimary ? 'add_product_primary'.tr : null,
                              ),
                          ],
                        )),
                    SizedBox(height: 18.dp),
                    AppTextField(
                      label: 'add_product_name'.tr,
                      hint: 'add_product_name_hint'.tr,
                      controller: _nameCtrl,
                    ),
                    SizedBox(height: 16.dp),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'add_product_price'.tr,
                            hint: '0.00',
                            controller: _priceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            prefixText: '\$ ',
                          ),
                        ),
                        SizedBox(width: 12.dp),
                        Expanded(
                          child: Obx(() => AppPickerField(
                                label: 'add_product_currency'.tr,
                                hint: 'USD',
                                value: state.currency.value,
                                icon: Icons.keyboard_arrow_down_rounded,
                                onTap: () => _pickCurrency(context, state, sendAction),
                              )),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.dp),
                    Obx(() => AppPickerField(
                          label: 'add_product_category'.tr,
                          hint: 'add_product_category_hint'.tr,
                          value: state.category.value.isEmpty
                              ? null
                              : state.category.value.tr,
                          icon: Icons.keyboard_arrow_down_rounded,
                          onTap: () => _pickCategory(context, state, sendAction),
                        )),
                    SizedBox(height: 16.dp),
                    AppTextField(
                      label: 'add_product_short_desc'.tr,
                      hint: 'add_product_short_desc_hint'.tr,
                      controller: _shortDescCtrl,
                    ),
                    SizedBox(height: 16.dp),
                    AppTextField(
                      label: 'add_product_detailed_desc'.tr,
                      hint: 'add_product_detailed_desc_hint'.tr,
                      controller: _detailedDescCtrl,
                      maxLines: 5,
                      minLines: 3,
                      maxLength: 500,
                      textInputAction: TextInputAction.newline,
                    ),
                    SizedBox(height: 24.dp),
                    Row(
                      children: [
                        Expanded(
                          child: SecondaryButton(
                            text: 'add_product_draft'.tr,
                            onTap: () => sendAction(SaveDraftRequested()),
                          ),
                        ),
                        SizedBox(width: 12.dp),
                        Expanded(
                          child: Obx(() => PrimaryButton(
                                text: 'add_product_publish'.tr,
                                isLoading: state.isSubmitting.value,
                                startIcon: const Icon(Icons.check_rounded, size: 18),
                                onTap: () => sendAction(PublishProductRequested(
                                  name: _nameCtrl.text,
                                  price: _priceCtrl.text,
                                  shortDescription: _shortDescCtrl.text,
                                  detailedDescription: _detailedDescCtrl.text,
                                )),
                              )),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCurrency(BuildContext context, AddProductState state, void Function(MyAction) sendAction) async {
    final picked = await showSimpleListPickerBottomSheet(
      context,
      title: 'add_product_currency'.tr,
      items: kProductCurrencies,
      selected: state.currency.value,
    );
    if (picked != null) sendAction(SelectCurrency(picked));
  }

  Future<void> _pickCategory(BuildContext context, AddProductState state, void Function(MyAction) sendAction) async {
    final labels = kProductCategoryKeys.map((k) => k.tr).toList();
    final picked = await showSimpleListPickerBottomSheet(
      context,
      title: 'add_product_category'.tr,
      items: labels,
      selected: state.category.value.isEmpty ? null : state.category.value.tr,
    );
    if (picked == null) return;
    final idx = labels.indexOf(picked);
    if (idx >= 0) sendAction(SelectCategory(kProductCategoryKeys[idx]));
  }
}
