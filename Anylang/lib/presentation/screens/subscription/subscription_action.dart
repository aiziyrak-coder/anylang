import '../../utils/screen_options/my_action.dart';
import 'subscription_plan.dart';

/// Faqat Tariflar (Obuna) ekraniga xos action'lar.
class SubscriptionAction extends MyAction {}

class SelectBillingCycle extends SubscriptionAction {
  final BillingCycle cycle;
  SelectBillingCycle(this.cycle);
}

class SelectPlan extends SubscriptionAction {
  final SubscriptionPlan plan;
  SelectPlan(this.plan);
}

class CancelSubscription extends SubscriptionAction {}
