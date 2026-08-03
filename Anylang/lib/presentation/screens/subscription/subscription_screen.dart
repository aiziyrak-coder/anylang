import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/core/buildNetwork/network_client.dart';
import '../../../data/core/mappers.dart';
import '../../../data/local/session_store.dart';
import '../../../data/network/payment_repository.dart';
import '../../../data/network/profile_repository.dart';
import '../../modal/payment_confirm_bottom_sheet.dart';
import '../../ui/items/plan_card.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/auth_validators.dart';
import '../../utils/money_format.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../products/products_state.dart';
import '../profile/profile_state.dart';
import 'subscription_action.dart';
import 'subscription_content.dart';
import 'subscription_plan.dart';
import 'subscription_state.dart';

class SubscriptionScreen extends Screen<SubscriptionState, void> {
  SubscriptionScreen() : super(mobileContent: SubscriptionContent());

  int? _pendingPaymentId;
  Timer? _pollTimer;
  bool _polling = false;
  AppLifecycleListener? _lifecycle;

  @override
  void initState(void payload) {
    state.loading.value = true;
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (_pendingPaymentId != null) {
          unawaited(_pollPendingPayment(showWaiting: false));
        }
      },
    );
    unawaited(_loadAll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _lifecycle?.dispose();
    _pendingPaymentId = null;
    state.awaitingPayment.value = false;
    state.checkoutInFlight.value = false;
    super.dispose();
  }

  String _money(String amount) {
    final cleaned = amount.replaceAll(RegExp(r'[^0-9.\-]'), '');
    if (cleaned.isEmpty) return amount;
    return formatMoneyAmount(cleaned, currency: 'UZS');
  }

  Future<void> _loadAll() async {
    state.loading.value = true;
    state.loadError.value = false;
    try {
      await _refreshMe();
      await _loadPlans();
    } finally {
      state.loading.value = false;
    }
  }

  Future<void> _refreshMe() async {
    final result = await Get.find<ProfileRepository>().getMe();
    result.when(
      success: (data) {
        final map = asMap(data);
        if (map == null) return;
        unawaited(SessionStore.saveUser(Map<String, dynamic>.from(map)));
        final country = (map['country']?.toString() ?? '').trim().toUpperCase();
        if (country.length == 2) {
          state.userCountry.value = country;
        } else {
          final fromSession =
              (SessionStore.user()?['country']?.toString() ?? '')
                  .trim()
                  .toUpperCase();
          state.userCountry.value =
              fromSession.length == 2 ? fromSession : null;
        }
        // Click · so‘m — hamma uchun.
        state.payMethod.value = 'click';
        state.displayCurrency.value = 'UZS';
        state.priceCurrencyPrefix.value = 'UZS';
        final isBiz = map['is_business'] == true;
        if (Get.isRegistered<ProductsState>()) {
          Get.find<ProductsState>().isBusiness.value = isBiz;
        }
        if (Get.isRegistered<ProfileState>()) {
          final ps = Get.find<ProfileState>();
          final acc = ps.account.value;
          if (acc != null && acc.isBusiness != isBiz) {
            // Soft flag — to‘liq reload subscription ekranidan chiqqanda.
            unawaited(ps.softRefreshHandler?.call());
          }
        }
        final sub = map['subscription'];
        if (sub is Map) {
          state.currentPlanCode.value =
              sub['plan']?.toString().toLowerCase();
          state.expiresAtIso.value = sub['expires_at']?.toString();
          state.autoRenew.value = sub['auto_renew'] == true;
        } else {
          state.currentPlanCode.value = null;
          state.expiresAtIso.value = null;
          state.autoRenew.value = false;
        }
      },
      failure: (err) {
        state.loadError.value = true;
        showAppError(err);
      },
    );
  }

  Future<void> _loadPlans() async {
    final client = Get.find<NetworkClient>();
    final lang = SessionStore.appLanguage();
    // Country fallback if /me failed partially.
    if (state.userCountry.value == null) {
      final fromSession =
          (SessionStore.user()?['country']?.toString() ?? '')
              .trim()
              .toUpperCase();
      if (fromSession.length == 2) {
        state.userCountry.value = fromSession;
      }
    }
    state.payMethod.value = 'click';
    state.displayCurrency.value = 'UZS';
    final result = await client.get(
      api: 'api/v1/subscription/plans',
      queryParameters: {
        'language': lang,
        'currency': 'UZS',
      },
    );
    result.when(
      success: (data) {
        if (data is! Map || data['plans'] is! List) {
          state.loadError.value = true;
          return;
        }
        final apiCurrency = data['currency']?.toString().trim().toUpperCase();
        // Catalog always UZS (Click); ignore leftover USD from old servers.
        state.displayCurrency.value = 'UZS';
        state.priceCurrencyPrefix.value =
            (apiCurrency == 'UZS' || apiCurrency == null || apiCurrency.isEmpty)
                ? 'UZS'
                : (apiCurrency.length <= 3 ? apiCurrency : 'UZS');
        final apiCountry =
            (data['user_country']?.toString() ?? '').trim().toUpperCase();
        if (apiCountry.length == 2) {
          state.userCountry.value = apiCountry;
        }
        final methods = data['payment_methods'];
        if (methods is List) {
          for (final m in methods) {
            if (m is! Map) continue;
            final code = m['code']?.toString();
            final available = m['available'] == true;
            if (code == 'click') state.clickPayAvailable.value = available;
          }
        }
        final taxPct = data['payment_tax_percent'];
        if (taxPct is num) {
          state.paymentTaxPercent.value = taxPct.toInt();
        } else if (taxPct is String) {
          final parsed = int.tryParse(taxPct);
          if (parsed != null) state.paymentTaxPercent.value = parsed;
        }
        var currentCode = state.currentPlanCode.value;
        if (currentCode == null) {
          final userPlan = SessionStore.user()?['subscription'];
          if (userPlan is Map) {
            currentCode = userPlan['plan']?.toString().toLowerCase();
          }
        }
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
          final yearlyTotal = raw['yearly_total']?.toString();
          final savings = raw['savings_percent'];
          String price(String? v) =>
              v == null || v.isEmpty ? '' : _money(v.replaceAll('\$', ''));
          final code = raw['code']?.toString() ?? '';
          final isCurrent = currentCode != null &&
              currentCode == code.toLowerCase();
          final periods = <int, PlanPeriod>{};
          final periodsRaw = raw['periods'];
          if (periodsRaw is List) {
            for (final p in periodsRaw) {
              if (p is! Map) continue;
              final months = p['months'];
              final m = months is int
                  ? months
                  : (months is num ? months.toInt() : int.tryParse('$months'));
              if (m == null) continue;
              final sp = p['savings_percent'];
              periods[m] = PlanPeriod(
                months: m,
                total: price(p['total']?.toString()),
                perMonth: price(p['per_month']?.toString()),
                tax: price(p['tax']?.toString()),
                totalWithTax: price(p['total_with_tax']?.toString()),
                taxPercent: () {
                  final tp = p['tax_percent'];
                  if (tp is int) return tp;
                  if (tp is num) return tp.toInt();
                  return state.paymentTaxPercent.value;
                }(),
                savingsPercent: sp is int
                    ? sp
                    : (sp is num ? sp.toInt() : null),
              );
            }
          }
          items.add(SubscriptionPlan(
            code: code,
            title: raw['title']?.toString() ?? '',
            isFree: raw['is_free'] == true,
            monthlyPrice: price(monthly),
            yearlyPrice: price(yearly),
            yearlyTotal: yearlyTotal != null ? price(yearlyTotal) : null,
            savingsPercent: savings is int
                ? savings
                : (savings is num ? savings.toInt() : null),
            badgeText: isCurrent
                ? 'subscription_badge_current'.tr
                : raw['badge']?.toString(),
            features: features,
            isCurrent: isCurrent,
            periods: periods,
          ));
        }
        if (items.isEmpty) {
          state.loadError.value = true;
          if (kDebugMode) {
            state.plans.assignAll(kMockSubscriptionPlans);
          }
        } else {
          state.plans
            ..clear()
            ..addAll(items);
          state.loadError.value = false;
          if (state.promoPlanCode.value == null) {
            for (final p in items) {
              if (!p.isFree) {
                state.promoPlanCode.value = p.code;
                break;
              }
            }
          }
        }
      },
      failure: (err) {
        showAppError(err);
        state.loadError.value = true;
        if (kDebugMode && state.plans.isEmpty) {
          state.plans.assignAll(kMockSubscriptionPlans);
        }
      },
    );
  }

  @override
  Future<void> actionHandler(SubscriptionState state, MyAction action) async {
    switch (action) {
      case Back _:
        popBackNavigate();
      case SelectBillingMonths a:
        state.billingMonths.value = a.months;
        state.promoPreview.value = null;
      case SelectPayMethod _:
        // Visa o‘chirilgan — faqat Click · so‘m.
        state.payMethod.value = 'click';
        state.displayCurrency.value = 'UZS';
      case RetryLoadPlans _:
        await _loadAll();
      case CheckPendingPayment _:
        await _pollPendingPayment(showWaiting: true);
      case SelectPlan a:
        state.promoPlanCode.value = a.plan.code;
        await _selectPlan(a.plan);
      case CancelSubscription _:
        await _cancelSubscription();
      case ApplyPromoCode _:
        await _applyPromo();
      case ClearPromoCode _:
        state.promoPreview.value = null;
        state.promoInput.value = '';
    }
  }

  Future<void> _applyPromo() async {
    final code = state.promoInput.value.trim();
    if (code.isEmpty) {
      showAppMessage('subscription_promo_empty'.tr);
      return;
    }
    // Preview against first paid plan for UX; checkout re-validates per plan.
    SubscriptionPlan? paid;
    final targetCode = state.promoPlanCode.value;
    if (targetCode != null) {
      for (final p in state.plans) {
        if (p.code == targetCode && !p.isFree) {
          paid = p;
          break;
        }
      }
    }
    paid ??= () {
      for (final p in state.plans) {
        if (!p.isFree) return p;
      }
      return null;
    }();
    if (paid == null) {
      showAppMessage('subscription_promo_need_plan'.tr);
      return;
    }
    state.promoLoading.value = true;
    final payments = Get.find<PaymentRepository>();
    final result = await payments.validatePromo(
      code: code,
      plan: paid.code,
      billingCycle: '${state.billingMonths.value}',
    );
    state.promoLoading.value = false;
    result.when(
      success: (data) {
        final map = asMap(data);
        if (map == null) return;
        state.promoPreview.value = PromoPreview(
          code: map['code']?.toString() ?? code.toUpperCase(),
          amountBefore: map['amount_before']?.toString() ?? '',
          discountAmount: map['discount_amount']?.toString() ?? '',
          amountAfter: map['amount_after']?.toString() ?? '',
        );
        showAppMessage('subscription_promo_ok'.tr);
      },
      failure: showAppError,
    );
  }

  Future<void> _cancelSubscription() async {
    final expires = state.expiresAtIso.value;
    final content = expires != null && expires.isNotEmpty
        ? 'subscription_cancel_confirm_until'.trParams({
            'date': _formatExpires(expires),
          })
        : 'subscription_cancel_confirm'.tr;
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: Text('subscription_cancel'.tr),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('common_cancel'.tr),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text(
              'subscription_cancel'.tr,
              style: const TextStyle(color: Color(0xFFB42318)),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final client = Get.find<NetworkClient>();
    final result = await client.post(api: 'api/v1/subscription/cancel');
    result.when(
      success: (data) async {
        final map = asMap(data);
        if (map != null) {
          await SessionStore.saveUser(Map<String, dynamic>.from(map));
        }
        showAppMessage(
          expires != null && expires.isNotEmpty
              ? 'subscription_cancelled_until'.trParams({
                  'date': _formatExpires(expires),
                })
              : 'subscription_cancelled'.tr,
        );
        await _loadAll();
      },
      failure: showAppError,
    );
  }

  Future<void> _selectPlan(SubscriptionPlan plan) async {
    if (state.checkoutInFlight.value || state.awaitingPayment.value) return;
    state.checkoutInFlight.value = true;
    try {
      await _selectPlanBody(plan);
    } finally {
      state.checkoutInFlight.value = false;
    }
  }

  Future<void> _selectPlanBody(SubscriptionPlan plan) async {
    final current = state.currentPlanCode.value;
    final onPaid = current != null &&
        current != 'basic' &&
        (state.expiresAtIso.value?.isNotEmpty ?? false);

    // Switching to Basic while on a paid plan = cancel renew at period end.
    if (plan.isFree || plan.code == 'basic') {
      if (onPaid && current != 'basic') {
        final ok = await Get.dialog<bool>(
          AlertDialog(
            title: Text('subscription_downgrade_title'.tr),
            content: Text(
              'subscription_downgrade_body'.trParams({
                'date': _formatExpires(state.expiresAtIso.value!),
              }),
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: Text('common_cancel'.tr),
              ),
              TextButton(
                onPressed: () => Get.back(result: true),
                child: Text('subscription_cancel'.tr),
              ),
            ],
          ),
        );
        if (ok == true) {
          final client = Get.find<NetworkClient>();
          final result =
              await client.post(api: 'api/v1/subscription/cancel');
          result.when(
            success: (data) async {
              final map = asMap(data);
              if (map != null) {
                await SessionStore.saveUser(Map<String, dynamic>.from(map));
              }
              showAppMessage(
                'subscription_cancelled_until'.trParams({
                  'date': _formatExpires(state.expiresAtIso.value!),
                }),
              );
              await _loadAll();
            },
            failure: showAppError,
          );
        }
        return;
      }
      final client = Get.find<NetworkClient>();
      final result = await client.post(
        api: 'api/v1/subscription/subscribe',
        data: {'plan': 'basic'},
      );
      result.when(
        success: (data) async {
          final map = asMap(data);
          if (map != null) {
            await SessionStore.saveUser(Map<String, dynamic>.from(map));
          }
          showAppMessage('subscription_basic_activated'.tr);
          await _loadAll();
        },
        failure: showAppError,
      );
      return;
    }

    final payments = Get.find<PaymentRepository>();
    final cycle = '${state.billingMonths.value}';
    final months = state.billingMonths.value;
    final promo = state.promoPreview.value?.code ??
        (state.promoInput.value.trim().isEmpty
            ? null
            : state.promoInput.value.trim());

    // Faqat Click · so‘m (Visa/Payme hozir yo‘q).
    if (!state.clickPayAvailable.value) {
      showAppError('subscription_payment_failed'.tr);
      return;
    }
    final checkout = await payments.checkoutSubscription(
      plan: plan.code,
      billingCycle: cycle,
      promoCode: promo,
      provider: 'click',
    );

    await checkout.when<Future<void>>(
      success: (data) async {
        if (data is! Map) return;
        final id = data['id'] ?? data['payment_id'];
        final checkoutUrl = data['checkout_url']?.toString();
        final mockConfirm = data['mock_confirm'] == true;
        final currency = (data['currency']?.toString() ?? 'UZS').toUpperCase();
        final amount = data['amount']?.toString() ?? '';
        final beforeTax = data['amount_before_tax']?.toString();
        final taxAmount = data['tax_amount']?.toString();
        final taxPctRaw = data['tax_percent'];
        final taxPct = taxPctRaw is num
            ? taxPctRaw.toInt()
            : int.tryParse('$taxPctRaw') ?? state.paymentTaxPercent.value;

        final periodKey = switch (months) {
          1 => 'subscription_period_1',
          3 => 'subscription_period_3',
          6 => 'subscription_period_6',
          _ => 'subscription_period_12',
        };

        final confirmed = await showPaymentConfirmBottomSheet(
          context,
          title: 'subscription_pay_confirm_title'.tr,
          subtitle: 'payment_confirm_subtitle'.tr,
          amount: amount,
          currency: currency,
          amountBeforeTax: beforeTax,
          taxAmount: taxAmount,
          taxPercent: taxPct,
          planLabel: plan.title,
          periodLabel: periodKey.tr,
          ctaText: 'subscription_pay_confirm_cta'.tr,
        );
        if (confirmed != true) {
          showAppMessage('payment_confirm_later_hint'.tr);
          return;
        }

        if (checkoutUrl != null &&
            checkoutUrl.isNotEmpty &&
            mockConfirm != true) {
          final uri = Uri.tryParse(checkoutUrl);
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
          if (id is num) {
            _pendingPaymentId = id.toInt();
            state.awaitingPayment.value = true;
            _startPollLoop();
            showAppMessage('subscription_checkout_opened'.tr);
          }
          return;
        }

        if (id is num && (kDebugMode || mockConfirm == true)) {
          final confirm = await payments.confirmMock(id.toInt());
          await confirm.when(
            success: (_) async {
              showAppMessage(
                'subscription_activated'.trParams({'plan': plan.title}),
              );
              await _loadAll();
            },
            failure: (e) async => showAppError(e),
          );
        } else {
          showAppMessage('subscription_checkout_opened'.tr);
        }
      },
      failure: (e) async {
        if (AuthValidators.hasErrorCode(e, 'PAYMENT_PROVIDER_COMING_SOON') ||
            AuthValidators.hasErrorCode(e, 'PAYMENT_UNAVAILABLE')) {
          showAppError('subscription_payment_failed'.tr);
          return;
        }
        showAppError(e);
      },
    );
  }

  void _startPollLoop() {
    _pollTimer?.cancel();
    var attempts = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_polling) return;
      attempts++;
      final done = await _pollPendingPayment(showWaiting: false);
      if (done || attempts >= 40) {
        _pollTimer?.cancel();
        if (!done && attempts >= 40) {
          state.awaitingPayment.value = false;
          _pendingPaymentId = null;
          showAppMessage('subscription_payment_check_hint'.tr);
        }
      }
    });
  }

  /// Returns true when payment resolved (paid or failed).
  Future<bool> _pollPendingPayment({required bool showWaiting}) async {
    final id = _pendingPaymentId;
    if (id == null) {
      if (showWaiting) showAppMessage('subscription_payment_check_hint'.tr);
      return true;
    }
    if (_polling) return false;
    _polling = true;
    try {
      final payments = Get.find<PaymentRepository>();
      final result = await payments.getPayment(id);
      var resolved = false;
      result.when(
        success: (data) {
          final map = asMap(data);
          final status = map?['status']?.toString().toLowerCase();
          if (status == 'paid' || status == 'succeeded' || status == 'completed') {
            resolved = true;
            _pendingPaymentId = null;
            state.awaitingPayment.value = false;
            _pollTimer?.cancel();
            showAppMessage('subscription_payment_success'.tr);
            unawaited(_loadAll());
          } else if (status == 'failed' ||
              status == 'canceled' ||
              status == 'cancelled') {
            resolved = true;
            _pendingPaymentId = null;
            state.awaitingPayment.value = false;
            _pollTimer?.cancel();
            showAppMessage('subscription_payment_failed'.tr);
          } else if (showWaiting) {
            showAppMessage('subscription_payment_pending'.tr);
          }
        },
        failure: (err) {
          if (showWaiting) showAppError(err);
        },
      );
      return resolved;
    } finally {
      _polling = false;
    }
  }

  String _formatExpires(String iso) {
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
