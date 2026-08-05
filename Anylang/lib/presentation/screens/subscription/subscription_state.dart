import 'package:get/get.dart';
import 'subscription_plan.dart';

class PromoPreview {
  final String code;
  final String amountBefore;
  final String discountAmount;
  final String amountAfter;

  const PromoPreview({
    required this.code,
    required this.amountBefore,
    required this.discountAmount,
    required this.amountAfter,
  });
}

class SubscriptionState extends GetxController {
  RxBool loading = true.obs;
  RxBool loadError = false.obs;
  RxBool awaitingPayment = false.obs;
  /// Checkout / cancel / subscribe so‘rovi ketayotganda ikki marta bosilmasin.
  RxBool checkoutInFlight = false.obs;
  RxBool promoLoading = false.obs;

  /// 1 | 3 | 6 | 12
  RxInt billingMonths = 12.obs;
  RxList<SubscriptionPlan> plans = <SubscriptionPlan>[].obs;

  RxnString currentPlanCode = RxnString();
  RxnString expiresAtIso = RxnString();
  RxBool autoRenew = false.obs;

  RxString promoInput = ''.obs;
  Rxn<PromoPreview> promoPreview = Rxn<PromoPreview>();
  /// Promo preview va checkout uchun tanlangan reja kodi.
  RxnString promoPlanCode = RxnString();
  /// Serverdan kelgan valyuta belgisi — katalog USD.
  RxString priceCurrencyPrefix = 'USD'.obs;
  /// Ko‘rsatilayotgan valyuta — katalog USD (Click charge UZS).
  RxString displayCurrency = 'USD'.obs;
  /// Foydalanuvchi mamlakati (ISO-2), masalan UZ.
  RxnString userCountry = RxnString();
  /// To‘lov usuli — faqat Click (so‘m).
  RxString payMethod = 'click'.obs;
  /// Server payment_methods: click available.
  RxBool clickPayAvailable = true.obs;
  RxBool visaPayAvailable = false.obs;
  /// To'lov solig'i foizi (default 2%) — plans API dan keladi.
  RxInt paymentTaxPercent = 2.obs;

  bool get isUzUser => (userCountry.value ?? '').toUpperCase() == 'UZ';
}
