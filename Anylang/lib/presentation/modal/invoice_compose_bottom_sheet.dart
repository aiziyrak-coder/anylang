import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../ui/buttons/primary_button.dart';
import '../ui/theme/colors.dart';
import '../utils/size_controller.dart';

class InvoiceDraft {
  final String title;
  final String amount;
  final String currency;
  final String note;

  const InvoiceDraft({
    required this.title,
    required this.amount,
    required this.currency,
    required this.note,
  });
}

Future<InvoiceDraft?> showInvoiceComposeBottomSheet(BuildContext context) {
  return showModalBottomSheet<InvoiceDraft>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => const _InvoiceComposeSheet(),
  );
}

class _InvoiceComposeSheet extends StatefulWidget {
  const _InvoiceComposeSheet();

  @override
  State<_InvoiceComposeSheet> createState() => _InvoiceComposeSheetState();
}

class _InvoiceComposeSheetState extends State<_InvoiceComposeSheet> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String _currency = 'USD';

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.dp)),
        ),
        padding: EdgeInsets.fromLTRB(20.dp, 14.dp, 20.dp, 24.dp),
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
              'chat_invoice_compose_title'.tr,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 14.dp),
            _field(c, _title, 'chat_invoice_title_hint'.tr),
            SizedBox(height: 10.dp),
            Row(
              children: [
                Expanded(
                  child: _field(
                    c,
                    _amount,
                    'chat_invoice_amount_hint'.tr,
                    keyboard: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                  ),
                ),
                SizedBox(width: 10.dp),
                _currencyChip(c, 'USD'),
                SizedBox(width: 6.dp),
                _currencyChip(c, 'UZS'),
                SizedBox(width: 6.dp),
                _currencyChip(c, 'EUR'),
              ],
            ),
            SizedBox(height: 10.dp),
            _field(c, _note, 'chat_invoice_note_hint'.tr, maxLines: 3),
            SizedBox(height: 16.dp),
            PrimaryButton(
              text: 'chat_invoice_send'.tr,
              onTap: () {
                final amount = _amount.text.trim().replaceAll(',', '.');
                if (amount.isEmpty) {
                  Get.snackbar('AnyLang', 'chat_invoice_amount_required'.tr);
                  return;
                }
                Navigator.pop(
                  context,
                  InvoiceDraft(
                    title: _title.text.trim().isEmpty
                        ? 'chat_invoice_default_title'.tr
                        : _title.text.trim(),
                    amount: amount,
                    currency: _currency,
                    note: _note.text.trim(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
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
        contentPadding: EdgeInsets.symmetric(horizontal: 14.dp, vertical: 12.dp),
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
