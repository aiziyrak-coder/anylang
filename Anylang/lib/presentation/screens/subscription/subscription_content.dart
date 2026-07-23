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
  Widget build(
    BuildContext context,
    SubscriptionState state,
    void Function(MyAction action) sendAction,
  ) {
    final c = context.appColors;

    return GradientBackground(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.dp, 4.dp, 16.dp, 0),
              child: AppTopBar(
                title: 'subscription_title'.tr,
                onBack: () => sendAction(Back()),
              ),
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
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4.dp),
                    Text(
                      'subscription_subtitle'.tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 13.sp,
                      ),
                    ),
                    Obx(() {
                      final plan = state.currentPlanCode.value;
                      final expires = state.expiresAtIso.value;
                      if (plan == null || plan == 'basic') {
                        return const SizedBox.shrink();
                      }
                      final date = _formatExpires(expires);
                      final renewOff = !state.autoRenew.value;
                      final text = renewOff && date != null
                          ? 'subscription_status_ending'.trParams({
                              'plan': plan.toUpperCase(),
                              'date': date,
                            })
                          : date != null
                              ? 'subscription_status_active'.trParams({
                                  'plan': plan.toUpperCase(),
                                  'date': date,
                                })
                              : 'subscription_status_active_nodate'
                                  .trParams({'plan': plan.toUpperCase()});
                      return Padding(
                        padding: EdgeInsets.only(top: 16.dp),
                        child: Container(
                          padding: EdgeInsets.all(12.dp),
                          decoration: BoxDecoration(
                            color: c.accentSoft,
                            borderRadius: BorderRadius.circular(12.dp),
                            border: Border.all(color: c.accent.withValues(alpha: 0.35)),
                          ),
                          child: Text(
                            text,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: c.accentText,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }),
                    Obx(() {
                      if (!state.awaitingPayment.value) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: EdgeInsets.only(top: 12.dp),
                        child: OutlinedButton(
                          onPressed: () =>
                              sendAction(CheckPendingPayment()),
                          child: Text('subscription_check_payment'.tr),
                        ),
                      );
                    }),
                    SizedBox(height: 20.dp),
                    Obx(
                      () => SegmentedToggle<BillingCycle>(
                        value: state.billingCycle.value,
                        onChanged: (cycle) =>
                            sendAction(SelectBillingCycle(cycle)),
                        options: [
                          SegmentOption(
                            value: BillingCycle.monthly,
                            label: 'subscription_monthly'.tr,
                          ),
                          SegmentOption(
                            value: BillingCycle.yearly,
                            label: 'subscription_yearly'.tr,
                            badge: '-20%',
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24.dp),
                    Obx(() {
                      if (state.loading.value && state.plans.isEmpty) {
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 32.dp),
                          child: const AppLoading(),
                        );
                      }
                      if (state.loadError.value && state.plans.isEmpty) {
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 40.dp),
                          child: Column(
                            children: [
                              Text(
                                'subscription_load_failed'.tr,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: c.textSecondary,
                                  fontSize: 14.sp,
                                ),
                              ),
                              SizedBox(height: 12.dp),
                              TextButton(
                                onPressed: () =>
                                    sendAction(RetryLoadPlans()),
                                child: Text('common_retry'.tr),
                              ),
                            ],
                          ),
                        );
                      }
                      return Column(
                        children: [
                          for (final plan in state.plans) ...[
                            _planCard(
                              plan,
                              state.billingCycle.value,
                              sendAction,
                            ),
                            SizedBox(height: 16.dp),
                          ],
                          if (state.plans
                              .any((p) => p.isCurrent && !p.isFree)) ...[
                            SizedBox(height: 8.dp),
                            TextButton(
                              onPressed: () =>
                                  sendAction(CancelSubscription()),
                              child: Text(
                                'subscription_cancel'.tr,
                                style: TextStyle(
                                  color: c.textSecondary,
                                  fontSize: 14.sp,
                                ),
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

  Widget _planCard(
    SubscriptionPlan plan,
    BillingCycle cycle,
    void Function(MyAction) sendAction,
  ) {
    String? note;
    if (!plan.isFree &&
        cycle == BillingCycle.yearly &&
        plan.yearlyTotal != null) {
      note = 'subscription_billed_yearly'.trParams({
        'total': plan.yearlyTotal!,
      });
    }
    return PlanCard(
      title: plan.title,
      price: plan.isFree ? 'subscription_free'.tr : plan.priceFor(cycle),
      priceSuffix: plan.isFree ? null : 'subscription_per_month'.tr,
      priceNote: note,
      features: plan.features,
      highlighted: plan.isCurrent,
      badgeText: plan.badgeText,
      badgeIcon: plan.isCurrent ? Icons.star_rounded : null,
      ctaText: plan.isCurrent
          ? 'subscription_current_plan_cta'.tr
          : 'subscription_choose_plan_cta'.tr,
      ctaEnabled: !plan.isCurrent,
      onCta: () => sendAction(SelectPlan(plan)),
    );
  }

  String? _formatExpires(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    try {
      final dt = DateTime.parse(iso).toLocal();
      final d = dt.day.toString().padLeft(2, '0');
      final m = dt.month.toString().padLeft(2, '0');
      return '$d.$m.${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}
