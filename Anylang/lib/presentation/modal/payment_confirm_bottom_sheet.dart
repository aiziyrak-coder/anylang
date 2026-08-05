import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../ui/buttons/primary_button.dart';
import '../ui/buttons/secondary_button.dart';
import '../ui/theme/colors.dart';
import '../ui/theme/gradients.dart';
import '../utils/money_format.dart';
import '../utils/size_controller.dart';

/// Premium to‘lov tasdiqlash sheet — ishonch + aniq Itogo.
Future<bool?> showPaymentConfirmBottomSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String amount,
  required String currency,
  String? amountBeforeTax,
  String? taxAmount,
  int taxPercent = 2,
  String? amountUsd,
  String? usdUzsRate,
  String? planLabel,
  String? periodLabel,
  String ctaText = '',
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return _PaymentConfirmSheet(
        title: title,
        subtitle: subtitle,
        amount: amount,
        currency: currency,
        amountBeforeTax: amountBeforeTax,
        taxAmount: taxAmount,
        taxPercent: taxPercent,
        amountUsd: amountUsd,
        usdUzsRate: usdUzsRate,
        planLabel: planLabel,
        periodLabel: periodLabel,
        ctaText: ctaText.isEmpty ? 'subscription_pay_confirm_cta'.tr : ctaText,
      );
    },
  );
}

class _PaymentConfirmSheet extends StatelessWidget {
  final String title;
  final String subtitle;
  final String amount;
  final String currency;
  final String? amountBeforeTax;
  final String? taxAmount;
  final int taxPercent;
  final String? amountUsd;
  final String? usdUzsRate;
  final String? planLabel;
  final String? periodLabel;
  final String ctaText;

  const _PaymentConfirmSheet({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.currency,
    required this.ctaText,
    this.amountBeforeTax,
    this.taxAmount,
    this.taxPercent = 2,
    this.amountUsd,
    this.usdUzsRate,
    this.planLabel,
    this.periodLabel,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final totalLabel = formatMoneyAmount(amount, currency: currency);
    final baseLabel = amountBeforeTax == null || amountBeforeTax!.isEmpty
        ? null
        : formatMoneyAmount(amountBeforeTax, currency: currency);
    final taxLabel = taxAmount == null || taxAmount!.isEmpty
        ? null
        : formatMoneyAmount(taxAmount, currency: currency);
    final showTax = baseLabel != null && taxLabel != null;
    final usdLabel = (amountUsd != null && amountUsd!.trim().isNotEmpty)
        ? formatMoneyAmount(amountUsd, currency: 'USD')
        : null;
    final rateHint = (usdUzsRate != null && usdUzsRate!.trim().isNotEmpty)
        ? '1 USD ≈ ${formatMoneyAmount(usdUzsRate, currency: 'UZS')}'
        : null;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: c.isDark ? const Color(0xFF0C2136) : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.dp)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20.dp, 12.dp, 20.dp, 20.dp),
          child: Column(
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
              Container(
                padding: EdgeInsets.all(16.dp),
                decoration: BoxDecoration(
                  gradient: profileIdCardGradient,
                  borderRadius: BorderRadius.circular(20.dp),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48.dp,
                      height: 48.dp,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14.dp),
                      ),
                      child: Icon(
                        Icons.verified_user_rounded,
                        color: Colors.white,
                        size: 26.dp,
                      ),
                    ),
                    SizedBox(width: 12.dp),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'payment_secure_title'.tr,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4.dp),
                          Text(
                            'payment_secure_subtitle'.tr,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontSize: 12.sp,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 18.dp),
              Text(
                title,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                SizedBox(height: 6.dp),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 13.sp,
                    height: 1.35,
                  ),
                ),
              ],
              if (planLabel != null || periodLabel != null) ...[
                SizedBox(height: 12.dp),
                Wrap(
                  spacing: 8.dp,
                  runSpacing: 8.dp,
                  children: [
                    if (planLabel != null && planLabel!.isNotEmpty)
                      _Pill(text: planLabel!, accent: true),
                    if (periodLabel != null && periodLabel!.isNotEmpty)
                      _Pill(text: periodLabel!, accent: false),
                  ],
                ),
              ],
              SizedBox(height: 16.dp),
              Container(
                padding: EdgeInsets.fromLTRB(16.dp, 16.dp, 16.dp, 14.dp),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(18.dp),
                  border: Border.all(color: c.surfaceBorder),
                  boxShadow: c.glassShadow,
                ),
                child: Column(
                  children: [
                    if (showTax) ...[
                      _AmountRow(
                        label: 'payment_subtotal'.tr,
                        value: baseLabel,
                        emphasize: false,
                      ),
                      SizedBox(height: 10.dp),
                      _AmountRow(
                        label: 'payment_tax_line'.trParams({
                          'percent': '$taxPercent',
                        }),
                        value: taxLabel,
                        emphasize: false,
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.dp),
                        child: Divider(height: 1, color: c.surfaceBorder),
                      ),
                    ],
                    _AmountRow(
                      label: 'payment_total'.tr,
                      value: totalLabel,
                      emphasize: true,
                    ),
                    if (usdLabel != null &&
                        currency.toUpperCase() == 'UZS') ...[
                      SizedBox(height: 8.dp),
                      _AmountRow(
                        label: 'USD',
                        value: usdLabel,
                        emphasize: false,
                      ),
                    ],
                    if (rateHint != null &&
                        currency.toUpperCase() == 'UZS') ...[
                      SizedBox(height: 6.dp),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          rateHint,
                          style: TextStyle(
                            color: c.textFaint,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 14.dp),
              Container(
                padding: EdgeInsets.all(12.dp),
                decoration: BoxDecoration(
                  color: c.accentSoft,
                  borderRadius: BorderRadius.circular(14.dp),
                  border: Border.all(color: c.accent.withValues(alpha: 0.28)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.payments_outlined, color: c.accent, size: 18.dp),
                    SizedBox(width: 8.dp),
                    Expanded(
                      child: Text(
                        'payment_methods_hint'.tr,
                        style: TextStyle(
                          color: c.accentText,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 18.dp),
              PrimaryButton(
                text: ctaText,
                endIcon: Icon(
                  Icons.arrow_forward_rounded,
                  color: c.onAccent,
                  size: 20.dp,
                ),
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.pop(context, true);
                },
              ),
              SizedBox(height: 10.dp),
              SecondaryButton(
                text: 'common_cancel'.tr,
                onTap: () => Navigator.pop(context, false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final bool accent;

  const _Pill({required this.text, required this.accent});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.dp, vertical: 6.dp),
      decoration: BoxDecoration(
        color: accent ? c.accentSoft : c.surface,
        borderRadius: BorderRadius.circular(99.dp),
        border: Border.all(
          color: accent ? c.accent.withValues(alpha: 0.4) : c.surfaceBorder,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: accent ? c.accentText : c.textSecondary,
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _AmountRow({
    required this.label,
    required this.value,
    required this.emphasize,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: emphasize ? c.textPrimary : c.textSecondary,
              fontSize: emphasize ? 15.sp : 13.sp,
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: emphasize ? c.accentText : c.textPrimary,
              fontSize: emphasize ? 20.sp : 14.sp,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}
