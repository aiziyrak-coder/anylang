import 'package:get/get.dart';
import 'subscription_plan.dart';

class SubscriptionState extends GetxController {
  Rx<BillingCycle> billingCycle = BillingCycle.yearly.obs;
  RxList<SubscriptionPlan> plans = <SubscriptionPlan>[].obs;
}
