import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/core/mappers.dart';
import '../../modal/simple_list_picker_bottom_sheet.dart';
import '../../ui/app_top_bar.dart';
import '../../ui/buttons/primary_button.dart';
import '../../ui/buttons/secondary_button.dart';
import '../../ui/gradient_background.dart';
import '../../ui/items/media_tile.dart';
import '../../ui/items/removable_chip.dart';
import '../../ui/product_capabilities.dart';
import '../../ui/keyboard_aware_scroll.dart';
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
/// qisqa/batafsil tavsif + Marketplace 2.0 maydonlari + qoralama/e'lon.
class AddProductContent extends ScreenContent<AddProductState> {

  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _shortDescCtrl;
  late final TextEditingController _detailedDescCtrl;
  late final TextEditingController _moqCtrl;
  late final TextEditingController _shippingCtrl;
  late final TextEditingController _videoCtrl;
  late final TextEditingController _factoryVideoCtrl;
  late final TextEditingController _processVideoCtrl;

  @override
  void initContent() {
    _nameCtrl = TextEditingController();
    _priceCtrl = TextEditingController();
    _shortDescCtrl = TextEditingController();
    _detailedDescCtrl = TextEditingController();
    _moqCtrl = TextEditingController();
    _shippingCtrl = TextEditingController();
    _videoCtrl = TextEditingController();
    _factoryVideoCtrl = TextEditingController();
    _processVideoCtrl = TextEditingController();
  }

  @override
  void onClose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _shortDescCtrl.dispose();
    _detailedDescCtrl.dispose();
    _moqCtrl.dispose();
    _shippingCtrl.dispose();
    _videoCtrl.dispose();
    _factoryVideoCtrl.dispose();
    _processVideoCtrl.dispose();
  }

  @override
  Widget build(BuildContext context, AddProductState state, FutureOr<void> Function(MyAction action) sendAction) {
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
                                filePath: state.images[i].filePath,
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
                          child: Obx(() {
                            final cur = state.currency.value;
                            final prefix = switch (cur) {
                              'EUR' => '€ ',
                              'RUB' => '₽ ',
                              'UZS' => 'so‘m ',
                              _ => '\$ ',
                            };
                            return AppTextField(
                              label: 'add_product_price'.tr,
                              hint: '0.00',
                              controller: _priceCtrl,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              prefixText: prefix,
                            );
                          }),
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
                    SizedBox(height: 20.dp),
                    Text(
                      'product_capabilities_title'.tr,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 6.dp),
                    Text(
                      'product_capabilities_hint'.tr,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 10.dp),
                    Obx(() {
                      return Wrap(
                        spacing: 8.dp,
                        runSpacing: 8.dp,
                        children: [
                          for (final code in kProductCapabilityCodes)
                            _CapabilityChip(
                              label: productCapabilityLabel(code),
                              selected: state.capabilities.contains(code),
                              onTap: () =>
                                  sendAction(ToggleProductCapability(code)),
                            ),
                        ],
                      );
                    }),
                    SizedBox(height: 20.dp),
                    Text(
                      'add_product_trade_section'.tr,
                      style: TextStyle(color: c.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 12.dp),
                    AppTextField(
                      label: 'product_moq'.tr,
                      hint: 'business_moq_hint'.tr,
                      controller: _moqCtrl,
                    ),
                    SizedBox(height: 16.dp),
                    AppTextField(
                      label: 'product_shipping'.tr,
                      hint: 'add_product_shipping_hint'.tr,
                      controller: _shippingCtrl,
                    ),
                    SizedBox(height: 16.dp),
                    Text(
                      'product_shipping_countries'.tr,
                      style: TextStyle(color: c.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 10.dp),
                    Obx(() => Wrap(
                          spacing: 10.dp,
                          runSpacing: 10.dp,
                          children: [
                            for (final code in state.shippingCountries)
                              RemovableChip(
                                label: formatCountryName(code),
                                onRemove: () => sendAction(RemoveShippingCountry(code)),
                              ),
                            RemovableChip.add(
                              label: 'business_add_export_country'.tr,
                              onTap: () => sendAction(AddShippingCountryRequested()),
                            ),
                          ],
                        )),
                    SizedBox(height: 20.dp),
                    Text(
                      'product_video_15s_title'.tr,
                      style: TextStyle(color: c.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 6.dp),
                    Text(
                      'product_video_15s_trust'.tr,
                      style: TextStyle(color: c.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 12.dp),
                    Obx(() {
                      final url = state.productVideoUrl.value;
                      final uploading = state.videoUploading.value;
                      final has = url != null && url.isNotEmpty;
                      return Material(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(16.dp),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16.dp),
                          onTap: uploading
                              ? null
                              : () => sendAction(PickProductVideoRequested()),
                          child: Ink(
                            padding: EdgeInsets.all(14.dp),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16.dp),
                              border: Border.all(color: c.outline),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48.dp,
                                  height: 48.dp,
                                  decoration: BoxDecoration(
                                    color: c.accentSoft,
                                    borderRadius: BorderRadius.circular(12.dp),
                                  ),
                                  child: uploading
                                      ? Padding(
                                          padding: EdgeInsets.all(12.dp),
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.dp,
                                            color: c.accent,
                                          ),
                                        )
                                      : Icon(
                                          has
                                              ? Icons.check_circle_rounded
                                              : Icons.play_circle_outline_rounded,
                                          color: c.accent,
                                          size: 28.dp,
                                        ),
                                ),
                                SizedBox(width: 12.dp),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        uploading
                                            ? 'product_video_uploading'.tr
                                            : has
                                                ? 'product_video_ready'.tr
                                                : 'product_video_add_cta'.tr,
                                        style: TextStyle(
                                          color: c.textPrimary,
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      SizedBox(height: 2.dp),
                                      Text(
                                        'product_video_15s_badge'.tr,
                                        style: TextStyle(
                                          color: c.textSecondary,
                                          fontSize: 12.sp,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (has && !uploading)
                                  IconButton(
                                    onPressed: () =>
                                        sendAction(ClearProductVideoRequested()),
                                    icon: Icon(
                                      Icons.close_rounded,
                                      color: c.textSecondary,
                                    ),
                                  )
                                else
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: c.textFaint,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    SizedBox(height: 20.dp),
                    Text(
                      'product_videos_title'.tr,
                      style: TextStyle(color: c.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 6.dp),
                    Text(
                      'add_product_videos_hint'.tr,
                      style: TextStyle(color: c.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 12.dp),
                    AppTextField(
                      label: 'product_video'.tr,
                      hint: 'add_product_video_hint'.tr,
                      controller: _videoCtrl,
                      keyboardType: TextInputType.url,
                    ),
                    SizedBox(height: 16.dp),
                    AppTextField(
                      label: 'product_factory_video'.tr,
                      hint: 'add_product_video_hint'.tr,
                      controller: _factoryVideoCtrl,
                      keyboardType: TextInputType.url,
                    ),
                    SizedBox(height: 16.dp),
                    AppTextField(
                      label: 'product_process_video'.tr,
                      hint: 'add_product_video_hint'.tr,
                      controller: _processVideoCtrl,
                      keyboardType: TextInputType.url,
                    ),
                    SizedBox(height: 24.dp),
                    Row(
                      children: [
                        Expanded(
                          child: Obx(() => SecondaryButton(
                            text: 'add_product_draft'.tr,
                            isLoading: state.isSubmitting.value,
                            enabled: !state.isSubmitting.value &&
                                !state.videoUploading.value,
                            onTap: () => sendAction(SaveDraftRequested(
                              name: _nameCtrl.text,
                              price: _priceCtrl.text,
                              shortDescription: _shortDescCtrl.text,
                              detailedDescription: _detailedDescCtrl.text,
                              moq: _moqCtrl.text,
                              shippingInfo: _shippingCtrl.text,
                              videoUrl: _videoCtrl.text,
                              factoryVideoUrl: _factoryVideoCtrl.text,
                              processVideoUrl: _processVideoCtrl.text,
                            )),
                          )),
                        ),
                        SizedBox(width: 12.dp),
                        Expanded(
                          child: Obx(() => PrimaryButton(
                                text: 'add_product_publish'.tr,
                                isLoading: state.isSubmitting.value,
                                enabled: !state.videoUploading.value,
                                startIcon: const Icon(Icons.check_rounded, size: 18),
                                onTap: () => sendAction(PublishProductRequested(
                                  name: _nameCtrl.text,
                                  price: _priceCtrl.text,
                                  shortDescription: _shortDescCtrl.text,
                                  detailedDescription: _detailedDescCtrl.text,
                                  moq: _moqCtrl.text,
                                  shippingInfo: _shippingCtrl.text,
                                  videoUrl: _videoCtrl.text,
                                  factoryVideoUrl: _factoryVideoCtrl.text,
                                  processVideoUrl: _processVideoCtrl.text,
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

class _CapabilityChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CapabilityChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final radius = BorderRadius.circular(99.dp);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          padding: EdgeInsets.symmetric(horizontal: 12.dp, vertical: 8.dp),
          decoration: BoxDecoration(
            color: selected ? c.accentSoft : c.surface,
            borderRadius: radius,
            border: Border.all(color: selected ? c.accent : c.outline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                size: 16.dp,
                color: selected ? kOnline : c.textFaint,
              ),
              SizedBox(width: 6.dp),
              Text(
                label,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
