import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../ui/buttons/primary_button.dart';
import '../ui/theme/colors.dart';
import '../utils/size_controller.dart';

class RfqDraft {
  final String product;
  final String quantity;
  final String unit;
  final String specs;
  final String deadline;

  const RfqDraft({
    required this.product,
    required this.quantity,
    required this.unit,
    required this.specs,
    required this.deadline,
  });
}

Future<RfqDraft?> showRfqComposeBottomSheet(BuildContext context) {
  return showModalBottomSheet<RfqDraft>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => const _RfqComposeSheet(),
  );
}

class _RfqComposeSheet extends StatefulWidget {
  const _RfqComposeSheet();

  @override
  State<_RfqComposeSheet> createState() => _RfqComposeSheetState();
}

class _RfqComposeSheetState extends State<_RfqComposeSheet> {
  late final TextEditingController _product;
  late final TextEditingController _quantity;
  late final TextEditingController _specs;
  late final TextEditingController _deadline;
  String _unit = 'pcs';

  @override
  void initState() {
    super.initState();
    _product = TextEditingController();
    _quantity = TextEditingController();
    _specs = TextEditingController();
    _deadline = TextEditingController();
  }

  @override
  void dispose() {
    _product.dispose();
    _quantity.dispose();
    _specs.dispose();
    _deadline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
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
                'chat_rfq_compose_title'.tr,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6.dp),
              Text(
                'chat_rfq_compose_hint'.tr,
                style: TextStyle(color: c.textSecondary, fontSize: 13.sp),
              ),
              SizedBox(height: 14.dp),
              _labeled(c, '📦 ${'chat_rfq_product'.tr}', _product,
                  'chat_rfq_product_hint'.tr),
              SizedBox(height: 10.dp),
              Text(
                '🔢 ${'chat_rfq_quantity'.tr}',
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
                      _quantity,
                      'chat_rfq_quantity_hint'.tr,
                      keyboard: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                    ),
                  ),
                  SizedBox(width: 8.dp),
                  _unitChip(c, 'pcs'),
                  SizedBox(width: 6.dp),
                  _unitChip(c, 'kg'),
                  SizedBox(width: 6.dp),
                  _unitChip(c, 'm'),
                ],
              ),
              SizedBox(height: 10.dp),
              _labeled(c, 'chat_rfq_specs'.tr, _specs, 'chat_rfq_specs_hint'.tr,
                  maxLines: 3),
              SizedBox(height: 10.dp),
              _labeled(
                c,
                'chat_rfq_deadline'.tr,
                _deadline,
                'chat_rfq_deadline_hint'.tr,
              ),
              SizedBox(height: 16.dp),
              PrimaryButton(
                text: 'chat_rfq_send'.tr,
                onTap: () {
                  final product = _product.text.trim();
                  final qty = _quantity.text.trim();
                  if (product.isEmpty) {
                    Get.snackbar('AnyLang', 'chat_rfq_product_required'.tr);
                    return;
                  }
                  if (qty.isEmpty) {
                    Get.snackbar('AnyLang', 'chat_rfq_quantity_required'.tr);
                    return;
                  }
                  Navigator.pop(
                    context,
                    RfqDraft(
                      product: product,
                      quantity: qty,
                      unit: _unit,
                      specs: _specs.text.trim(),
                      deadline: _deadline.text.trim(),
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

  Widget _unitChip(AppColors c, String code) {
    final selected = _unit == code;
    final label = 'chat_rfq_unit_$code'.tr;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _unit = code),
        borderRadius: BorderRadius.circular(10.dp),
        child: Ink(
          padding: EdgeInsets.symmetric(horizontal: 10.dp, vertical: 10.dp),
          decoration: BoxDecoration(
            color: selected ? c.accentSoft : c.background,
            borderRadius: BorderRadius.circular(10.dp),
            border: Border.all(color: selected ? c.accent : c.outline),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? c.accent : c.textSecondary,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
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

  Widget _field(
    AppColors c,
    TextEditingController ctrl,
    String hint, {
    TextInputType? keyboard,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      style: TextStyle(color: c.textPrimary, fontSize: 14.sp),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.textFaint, fontSize: 13.sp),
        filled: true,
        fillColor: c.background,
        contentPadding: EdgeInsets.symmetric(horizontal: 12.dp, vertical: 12.dp),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.dp),
          borderSide: BorderSide(color: c.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.dp),
          borderSide: BorderSide(color: c.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.dp),
          borderSide: BorderSide(color: c.accent),
        ),
      ),
    );
  }
}
