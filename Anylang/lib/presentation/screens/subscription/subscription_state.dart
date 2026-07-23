import 'package:get/get.dart';
import 'subscription_plan.dart';

class SubscriptionState extends GetxController {
  RxBool loading = true.obs;
  RxBool loadError = false.obs;
  RxBool awaitingPayment = false.obs;
  Rx<BillingCycle> billingCycle = BillingCycle.yearly.obs;
  RxList<SubscriptionPlan> plans = <SubscriptionPlan>[].obs;

  /// Live subscription snapshot from `/users/me`.
  RxnString currentPlanCode = RxnString();
  RxnString expiresAtIso = RxnString();
  RxBool autoRenew = false.obs;
}
