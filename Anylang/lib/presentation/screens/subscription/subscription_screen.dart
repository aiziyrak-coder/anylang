import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/core/buildNetwork/network_client.dart';
import '../../../data/network/payment_repository.dart';
import '../../ui/items/plan_card.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import 'subscription_action.dart';
import 'subscription_content.dart';
import 'subscription_plan.dart';
import 'subscription_state.dart';

class SubscriptionScreen extends Screen<SubscriptionState, void> {
  SubscriptionScreen() : super(mobileContent: SubscriptionContent());

  @override
  void initState(void payload) {
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    final client = Get.find<NetworkClient>();
    final result = await client.get(api: 'api/v1/subscription/plans');
    result.when(
      success: (data) {
        if (data is! Map || data['plans'] is! List) return;
        final items = <SubscriptionPlan>[];
        for (final raw in data['plans'] as List) {
          if (raw is! Map) continue;
          final featuresRaw = raw['features'];
          final features = <PlanFeature>[];
          if (featuresRaw is List) {
            for (final f in featuresRaw) {
              if (f is Map) {
                features.add(PlanFeature(
                  f['text']?.toString() ?? '',
                  included: f['included'] != false,
                ));
              }
            }
          }
          final monthly = raw['monthly_price']?.toString();
          final yearly = raw['yearly_price']?.toString();
          items.add(SubscriptionPlan(
            code: raw['code']?.toString() ?? '',
            title: raw['title']?.toString() ?? '',
            isFree: raw['is_free'] == true,
            monthlyPrice: monthly != null ? '\$$monthly' : '',
            yearlyPrice: yearly != null ? '\$$yearly' : '',
            badgeText: raw['badge']?.toString(),
            features: features,
          ));
        }
        if (items.isNotEmpty) {
          state.plans
            ..clear()
            ..addAll(items);
        }
      },
      failure: (_) {},
    );
  }

  @override
  Future<void> actionHandler(SubscriptionState state, MyAction action) async {
    switch (action) {
      case Back _:
        popBackNavigate();
      case SelectBillingCycle a:
        state.billingCycle.value = a.cycle;
      case SelectPlan a:
        await _selectPlan(a.plan);
    }
  }

  Future<void> _selectPlan(SubscriptionPlan plan) async {
    if (plan.isFree || plan.code == 'basic') {
      final client = Get.find<NetworkClient>();
      final result = await client.post(
        api: 'api/v1/subscription/subscribe',
        data: {'plan': 'basic'},
      );
      result.when(
        success: (_) {
          showAppMessage('Basic tarif faollashtirildi');
          popBackNavigate();
        },
        failure: showAppError,
      );
      return;
    }

    final payments = Get.find<PaymentRepository>();
    final cycle =
        state.billingCycle.value == BillingCycle.yearly ? 'yearly' : 'monthly';
    final checkout = await payments.checkoutSubscription(
      plan: plan.code,
      billingCycle: cycle,
    );

    await checkout.when<Future<void>>(
      success: (data) async {
        if (data is! Map) return;
        final id = data['id'];
        final checkoutUrl = data['checkout_url']?.toString();
        final mockConfirm = data['mock_confirm'] == true;

        if (checkoutUrl != null &&
            checkoutUrl.isNotEmpty &&
            mockConfirm != true) {
          final uri = Uri.tryParse(checkoutUrl);
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            showAppMessage("To'lov sahifasi ochildi");
          }
          return;
        }

        if (id is num) {
          final confirm = await payments.confirmMock(id.toInt());
          confirm.when(
            success: (_) {
              showAppMessage('${plan.title} faollashtirildi');
              popBackNavigate();
            },
            failure: showAppError,
          );
        }
      },
      failure: (e) async {
        showAppError(e);
      },
    );
  }
}
