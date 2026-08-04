import 'package:get/get.dart';

/// To‘lov usuli API kodi → foydalanuvchiga tushunarli matn.
String paymentMethodLabel(String code) {
  switch (code.trim()) {
    case 'T/T':
      return 'payment_method_tt'.tr;
    case 'L/C':
      return 'payment_method_lc'.tr;
    case 'Western Union':
      return 'payment_method_western_union'.tr;
    case 'PayPal':
      return 'payment_method_paypal'.tr;
    case 'Escrow':
      return 'payment_method_escrow'.tr;
    case 'Cash':
      return 'payment_method_cash'.tr;
    default:
      return code;
  }
}

String formatPaymentMethods(Iterable<String> codes) {
  return codes.map(paymentMethodLabel).join(' · ');
}
