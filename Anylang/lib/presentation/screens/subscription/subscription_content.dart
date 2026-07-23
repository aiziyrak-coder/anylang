import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../ui/app_loading.dart';
import '../../ui/app_top_bar.dart';
import '../../ui/gradient_background.dart';
import '../../ui/items/plan_card.dart';
import '../../ui/items/segmented_toggle.dart';
import '../../ui/theme/colors.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import 'subscription_action.dart';
import 'subscription_plan.dart';
import 'subscription_state.dart';

/// S16 — Tariflar / Obuna. Oylik/Yillik davr tanlanadi, 3 ta tarif kartasi
/// (Basic/Premium/Business) ko'rsatiladi.
class SubscriptionContent extends ScreenContent<SubscriptionState> {

  @override
  Widget build(BuildContext context, SubscriptionState state, void Function(MyAction action) sendAction) {
    final c = context.appColors;

    return GradientBackground(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.dp, 4.dp, 16.dp, 0),
              child: AppTopBar(title: 'subscription_title'.tr, onBack: () => sendAction(Back())),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20.dp, 16.dp, 20.dp, 24.dp),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'subscription_headline'.tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.textPrimary, fontSize: 22.sp, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 4.dp),
                    Text(
                      'subscription_subtitle'.tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: c.textSecondary, fontSize: 13.sp),
                    ),
                    SizedBox(height: 20.dp),
                    Obx(() => SegmentedToggle<BillingCycle>(
                          value: state.billingCycle.value,
                          onChanged: (cycle) => sendAction(SelectBillingCycle(cycle)),
                          options: [
                            SegmentOption(value: BillingCycle.monthly, label: 'subscription_monthly'.tr),
                            SegmentOption(
                              value: BillingCycle.yearly,
                              label: 'subscription_yearly'.tr,
                              badge: '-20%',
                            ),
                          ],
                        )),
                    SizedBox(height: 24.dp),
                    Obx(() {
                      if (state.loading.value && state.plans.isEmpty) {
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 32.dp),
                          child: const AppLoading(),
                        );
                      }
                      return Column(
                        children: [
                          for (final plan in state.plans) ...[
                            _planCard(plan, state.billingCycle.value, sendAction),
                            SizedBox(height: 16.dp),
                          ],
                          if (state.plans.any((p) => p.isCurrent && !p.isFree)) ...[
                            SizedBox(height: 8.dp),
                            TextButton(
                              onPressed: () => sendAction(CancelSubscription()),
                              child: Text(
                                'subscription_cancel'.tr,
                                style: TextStyle(color: c.textSecondary, fontSize: 14.sp),
                              ),
                            ),
                          ],
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _planCard(SubscriptionPlan plan, BillingCycle cycle, void Function(MyAction) sendAction) {
    return PlanCard(
      title: plan.title,
      price: plan.isFree ? 'subscription_free'.tr : plan.priceFor(cycle),
      priceSuffix: plan.isFree ? null : 'subscription_per_month'.tr,
      features: plan.features,
      highlighted: plan.isCurrent,
      badgeText: plan.badgeText,
      badgeIcon: plan.isCurrent ? Icons.star_rounded : null,
      ctaText: plan.isCurrent ? 'subscription_current_plan_cta'.tr : 'subscription_choose_plan_cta'.tr,
      ctaEnabled: !plan.isCurrent,
      onCta: () => sendAction(SelectPlan(plan)),
    );
  }
}
