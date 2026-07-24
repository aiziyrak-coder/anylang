import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../ui/app_loading.dart';
import '../../ui/app_top_bar.dart';
import '../../ui/buttons/primary_button.dart';
import '../../ui/gradient_background.dart';
import '../../ui/items/plan_card.dart';
import '../../ui/items/segmented_toggle.dart';
import '../../ui/textfields/app_text_field.dart';
import '../../ui/theme/colors.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import 'subscription_action.dart';
import 'subscription_plan.dart';
import 'subscription_state.dart';

/// S16 — Tariflar / Obuna. 1/3/6/12 oy + promokod.
class SubscriptionContent extends ScreenContent<SubscriptionState> {
  final TextEditingController _promoCtrl = TextEditingController();

  @override
  void onClose() {
    _promoCtrl.dispose();
  }

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
                            border: Border.all(
                              color: c.accent.withValues(alpha: 0.35),
                            ),
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
                      () => SegmentedToggle<int>(
                        value: state.billingMonths.value,
                        onChanged: (months) =>
                            sendAction(SelectBillingMonths(months)),
                        options: [
                          SegmentOption(
                            value: 1,
                            label: 'subscription_period_1'.tr,
                          ),
                          SegmentOption(
                            value: 3,
                            label: 'subscription_period_3'.tr,
                          ),
                          SegmentOption(
                            value: 6,
                            label: 'subscription_period_6'.tr,
                          ),
                          SegmentOption(
                            value: 12,
                            label: 'subscription_period_12'.tr,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.dp),
                    _promoBlock(context, state, sendAction),
                    SizedBox(height: 20.dp),
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
                              state.billingMonths.value,
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

  Widget _promoBlock(
    BuildContext context,
    SubscriptionState state,
    void Function(MyAction) sendAction,
  ) {
    final c = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          label: 'subscription_promo_label'.tr,
          hint: 'subscription_promo_hint'.tr,
          controller: _promoCtrl,
          textInputAction: TextInputAction.done,
          onChanged: (v) => state.promoInput.value = v,
        ),
        SizedBox(height: 10.dp),
        Obx(() {
          final preview = state.promoPreview.value;
          final loading = state.promoLoading.value;
          return PrimaryButton(
            text: preview == null
                ? 'subscription_promo_apply'.tr
                : 'subscription_promo_clear'.tr,
            enabled: !loading,
            isLoading: loading,
            onTap: () {
              if (preview != null) {
                _promoCtrl.clear();
              }
              sendAction(
                preview == null ? ApplyPromoCode() : ClearPromoCode(),
              );
            },
          );
        }),
        Obx(() {
          final preview = state.promoPreview.value;
          if (preview == null) return const SizedBox.shrink();
          return Padding(
            padding: EdgeInsets.only(top: 10.dp),
            child: Container(
              padding: EdgeInsets.all(12.dp),
              decoration: BoxDecoration(
                color: c.accentSoft,
                borderRadius: BorderRadius.circular(12.dp),
                border: Border.all(color: c.accent.withValues(alpha: 0.35)),
              ),
              child: Text(
                'subscription_promo_discount'.trParams({
                  'code': preview.code,
                  'before': '\$${preview.amountBefore}',
                  'discount': '\$${preview.discountAmount}',
                  'after': '\$${preview.amountAfter}',
                }),
                style: TextStyle(
                  color: c.accentText,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _planCard(
    SubscriptionPlan plan,
    int months,
    void Function(MyAction) sendAction,
  ) {
    String? note;
    if (!plan.isFree) {
      final total = plan.totalFor(months);
      if (total != null && months > 1) {
        note = 'subscription_billed_period'.trParams({
          'months': '$months',
          'total': total,
        });
      }
      final savings = plan.savingsFor(months);
      if (savings != null && savings > 0) {
        final saveNote = 'subscription_save_percent'.trParams({
          'percent': '$savings',
        });
        note = note == null ? saveNote : '$note · $saveNote';
      }
    }
    return PlanCard(
      title: plan.title,
      price: plan.isFree ? 'subscription_free'.tr : plan.priceFor(months),
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
