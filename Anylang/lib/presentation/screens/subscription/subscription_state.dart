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
  RxBool promoLoading = false.obs;

  /// 1 | 3 | 6 | 12
  RxInt billingMonths = 12.obs;
  RxList<SubscriptionPlan> plans = <SubscriptionPlan>[].obs;

  RxnString currentPlanCode = RxnString();
  RxnString expiresAtIso = RxnString();
  RxBool autoRenew = false.obs;

  RxString promoInput = ''.obs;
  Rxn<PromoPreview> promoPreview = Rxn<PromoPreview>();
}
