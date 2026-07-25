import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../ui/buttons/primary_button.dart';
import '../ui/theme/colors.dart';
import '../utils/size_controller.dart';

class OfferDraft {
  final String product;
  final String price;
  final String currency;
  final String delivery;
  final String moq;
  final String payment;
  final int? productId;
  final String status;

  const OfferDraft({
    required this.product,
    required this.price,
    required this.currency,
    required this.delivery,
    required this.moq,
    required this.payment,
    this.productId,
    this.status = 'offered',
  });
}

Future<OfferDraft?> showOfferComposeBottomSheet(
  BuildContext context, {
  OfferDraft? initial,
}) {
  return showModalBottomSheet<OfferDraft>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _OfferComposeSheet(initial: initial),
  );
}

class _OfferComposeSheet extends StatefulWidget {
  final OfferDraft? initial;

  const _OfferComposeSheet({this.initial});

  @override
  State<_OfferComposeSheet> createState() => _OfferComposeSheetState();
}

class _OfferComposeSheetState extends State<_OfferComposeSheet> {
  late final TextEditingController _product;
  late final TextEditingController _price;
  late final TextEditingController _delivery;
  late final TextEditingController _moq;
  late final TextEditingController _payment;
  late String _currency;
  int? _productId;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _product = TextEditingController(text: i?.product ?? '');
    _price = TextEditingController(text: i?.price ?? '');
    _delivery = TextEditingController(text: i?.delivery ?? '');
    _moq = TextEditingController(text: i?.moq ?? '');
    _payment = TextEditingController(text: i?.payment ?? '');
    _currency = i?.currency ?? 'USD';
    _productId = i?.productId;
  }

  @override
  void dispose() {
    _product.dispose();
    _price.dispose();
    _delivery.dispose();
    _moq.dispose();
    _payment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final isCounter = widget.initial != null;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.dp)),
        ),
        padding: EdgeInsets.fromLTRB(20.dp, 14.dp, 20.dp, 24.dp),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44.dp,
                  height: 5.dp,
                  decoration: BoxDecoration(
                    color: c.outline,
                    borderRadius: BorderRadius.circular(5.dp),
                  ),
                ),
              ),
              SizedBox(height: 16.dp),
              Text(
                isCounter
                    ? 'chat_offer_counter_title'.tr
                    : 'chat_offer_compose_title'.tr,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6.dp),
              Text(
                'chat_offer_compose_hint'.tr,
                style: TextStyle(color: c.textSecondary, fontSize: 13.sp),
              ),
              SizedBox(height: 14.dp),
              _labeled(c, '📦 ${'chat_offer_product'.tr}', _product,
                  'chat_offer_product_hint'.tr),
              SizedBox(height: 10.dp),
              Text(
                '💵 ${'chat_offer_price'.tr}',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 6.dp),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      c,
                      _price,
                      'chat_offer_price_hint'.tr,
                      keyboard: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.dp),
                  _currencyChip(c, 'USD'),
                  SizedBox(width: 6.dp),
                  _currencyChip(c, 'UZS'),
                  SizedBox(width: 6.dp),
                  _currencyChip(c, 'EUR'),
                ],
              ),
              SizedBox(height: 10.dp),
              _labeled(c, '📅 ${'chat_offer_delivery'.tr}', _delivery,
                  'chat_offer_delivery_hint'.tr),
              SizedBox(height: 10.dp),
              _labeled(c, 'chat_offer_moq'.tr, _moq, 'chat_offer_moq_hint'.tr),
              SizedBox(height: 10.dp),
              _labeled(
                c,
                'chat_offer_payment'.tr,
                _payment,
                'chat_offer_payment_hint'.tr,
              ),
              SizedBox(height: 16.dp),
              PrimaryButton(
                text: isCounter
                    ? 'chat_offer_send_counter'.tr
                    : 'chat_offer_send'.tr,
                onTap: () {
                  final product = _product.text.trim();
                  final price = _price.text.trim().replaceAll(',', '.');
                  if (product.isEmpty) {
                    Get.snackbar('AnyLang', 'chat_offer_product_required'.tr);
                    return;
                  }
                  if (price.isEmpty) {
                    Get.snackbar('AnyLang', 'chat_offer_price_required'.tr);
                    return;
                  }
                  Navigator.pop(
                    context,
                    OfferDraft(
                      product: product,
                      price: price,
                      currency: _currency,
                      delivery: _delivery.text.trim(),
                      moq: _moq.text.trim(),
                      payment: _payment.text.trim(),
                      productId: _productId,
                      status: isCounter ? 'countered' : 'offered',
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _labeled(
    AppColors c,
    String label,
    TextEditingController ctrl,
    String hint, {
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 6.dp),
        _field(c, ctrl, hint, maxLines: maxLines),
      ],
    );
  }

  Widget _currencyChip(AppColors c, String code) {
    final on = _currency == code;
    return Material(
      color: on ? c.accent : c.background,
      borderRadius: BorderRadius.circular(10.dp),
      child: InkWell(
        onTap: () => setState(() => _currency = code),
        borderRadius: BorderRadius.circular(10.dp),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.dp, vertical: 12.dp),
          child: Text(
            code,
            style: TextStyle(
              color: on ? c.onAccent : c.textPrimary,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    AppColors c,
    TextEditingController ctrl,
    String hint, {
    int maxLines = 1,
    TextInputType? keyboard,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboard,
      inputFormatters: inputFormatters,
      style: TextStyle(color: c.textPrimary, fontSize: 15.sp),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.textFaint, fontSize: 14.sp),
        filled: true,
        fillColor: c.background,
        contentPadding:
            EdgeInsets.symmetric(horizontal: 14.dp, vertical: 12.dp),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.dp),
          borderSide: BorderSide(color: c.surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.dp),
          borderSide: BorderSide(color: c.surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.dp),
          borderSide: BorderSide(color: c.accent),
        ),
      ),
    );
  }
}
