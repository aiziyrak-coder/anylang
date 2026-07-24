import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/core/mappers.dart';
import '../../../data/local/session_store.dart';
import '../../../data/network/numbers_repository.dart';
import '../../../data/network/payment_repository.dart';
import '../../../data/network/profile_repository.dart';
import '../../ui/buttons/primary_button.dart';
import '../../ui/buttons/secondary_button.dart';
import '../../ui/theme/colors.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../../utils/size_controller.dart';
import 'number_models.dart';
import 'numbers_action.dart';
import 'numbers_content.dart';
import 'numbers_state.dart';

class NumbersScreen extends Screen<NumbersState, void> {
  NumbersScreen() : super(mobileContent: NumbersContent());

  int? _pendingPaymentId;
  Timer? _pollTimer;
  AppLifecycleListener? _lifecycle;
  Timer? _searchDebounce;

  @override
  void initState(void payload) {
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
    _searchDebounce?.cancel();
    _lifecycle?.dispose();
    _pendingPaymentId = null;
    state.awaitingPayment.value = false;
  }

  Future<void> _loadAll() async {
    state.loading.value = true;
    state.error.value = null;
    await Future.wait([_loadMine(), _loadGroups()]);
    await _loadCatalog(reset: true);
    state.loading.value = false;
  }

  Future<void> _loadMine() async {
    final result = await Get.find<NumbersRepository>().myNumber();
    result.when(
      success: (data) {
        final map = asMap(data);
        if (map == null) return;
        state.my.value = MyNumberInfo.fromApi(map);
      },
      failure: (err) {
        // Fallback from session
        final n = SessionStore.user()?['number']?.toString() ?? '';
        if (n.isNotEmpty) {
          state.my.value = MyNumberInfo(number: n);
        } else {
          state.error.value = err.toString();
        }
      },
    );
  }

  Future<void> _loadGroups() async {
    final result = await Get.find<NumbersRepository>().groups();
    result.when(
      success: (data) {
        final list = asList(data)
            .whereType<Map>()
            .map((e) => NumberGroupInfo.fromApi(Map<String, dynamic>.from(e)))
            .toList();
        state.groups.assignAll(list);
      },
      failure: showAppError,
    );
  }

  Future<void> _loadCatalog({required bool reset}) async {
    if (reset) {
      state.page.value = 1;
      state.catalogLoading.value = true;
    }
    final result = await Get.find<NumbersRepository>().catalog(
      search: state.searchQuery.value.trim().isEmpty
          ? null
          : state.searchQuery.value.trim(),
      groupId: state.selectedGroupId.value,
      hasBonus: state.hasBonusOnly.value ? true : null,
      sort: state.sort.value,
      page: state.page.value,
      limit: 30,
    );
    result.when(
      success: (data) {
        final map = asMap(data);
        if (map == null) return;
        final items = asList(map['items'])
            .whereType<Map>()
            .map((e) => CatalogNumber.fromApi(Map<String, dynamic>.from(e)))
            .toList();
        if (reset) {
          state.items.assignAll(items);
        } else {
          state.items.addAll(items);
        }
        state.hasMore.value = map['has_more'] == true;
        state.total.value = (map['total'] as num?)?.toInt() ?? items.length;
      },
      failure: showAppError,
    );
    state.catalogLoading.value = false;
  }

  @override
  Future<void> actionHandler(NumbersState state, MyAction action) async {
    switch (action) {
      case NumbersBack _:
        popBackNavigate();
      case NumbersRetry _:
        await _loadAll();
      case NumbersSearch a:
        state.searchQuery.value = a.query;
        _searchDebounce?.cancel();
        _searchDebounce = Timer(const Duration(milliseconds: 350), () {
          unawaited(_loadCatalog(reset: true));
        });
      case NumbersSelectGroup a:
        state.selectedGroupId.value = a.groupId;
        await _loadCatalog(reset: true);
      case NumbersToggleBonus _:
        state.hasBonusOnly.value = !state.hasBonusOnly.value;
        await _loadCatalog(reset: true);
      case NumbersChangeSort a:
        state.sort.value = a.sort;
        await _loadCatalog(reset: true);
      case NumbersLoadMore _:
        if (!state.hasMore.value || state.catalogLoading.value) return;
        state.page.value = state.page.value + 1;
        await _loadCatalog(reset: false);
      case NumbersRandomSwap _:
        await _randomSwap();
      case NumbersOpenItem a:
        await _showBuySheet(a.item);
      case NumbersBuy a:
        await _buy(a.item);
      case NumbersCheckPayment _:
        await _pollPendingPayment(showWaiting: true);
    }
  }

  Future<void> _randomSwap() async {
    final mine = state.my.value;
    if (mine != null && !mine.canChangeFree) {
      final days = (mine.cooldownSeconds / 86400).ceil().clamp(1, 90);
      showAppMessage('numbers_cooldown'.trParams({'days': '$days'}));
      return;
    }
    final ok = await Get.dialog<bool>(
          AlertDialog(
            title: Text('numbers_swap_title'.tr),
            content: Text('numbers_swap_body'.tr),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: Text('cancel'.tr),
              ),
              TextButton(
                onPressed: () => Get.back(result: true),
                child: Text('numbers_swap_confirm'.tr),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;

    state.purchasing.value = true;
    final result = await Get.find<NumbersRepository>().random();
    state.purchasing.value = false;
    await result.when(
      success: (data) async {
        final map = asMap(data);
        final number = map?['number']?.toString() ?? '';
        showAppMessage(
          'numbers_swap_success'.trParams({
            'number': formatNumber(number),
          }),
        );
        await _refreshUser();
        await _loadMine();
        await _loadCatalog(reset: true);
      },
      failure: (e) async => showAppError(e),
    );
  }

  Future<void> _showBuySheet(CatalogNumber item) async {
    final c = Get.context?.appColors;
    await Get.bottomSheet(
      SafeArea(
        child: Container(
          padding: EdgeInsets.fromLTRB(20.dp, 16.dp, 20.dp, 20.dp),
          decoration: BoxDecoration(
            color: c?.surface ?? Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22.dp)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40.dp,
                  height: 4.dp,
                  decoration: BoxDecoration(
                    color: (c?.outline ?? Colors.grey).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              SizedBox(height: 16.dp),
              Text(
                formatNumber(item.number),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: c?.textPrimary,
                ),
              ),
              SizedBox(height: 8.dp),
              Text(
                item.group.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: c?.accentText,
                ),
              ),
              SizedBox(height: 6.dp),
              Text(
                item.group.priceLabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w700,
                  color: c?.textPrimary,
                ),
              ),
              if (item.group.bonusPlan != null) ...[
                SizedBox(height: 10.dp),
                Text(
                  'numbers_bonus'.trParams({
                    'plan': item.group.bonusPlan!,
                    'months': '${item.group.bonusMonths ?? 0}',
                  }),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: c?.textSecondary,
                  ),
                ),
              ],
              SizedBox(height: 18.dp),
              PrimaryButton(
                text: item.group.isFree
                    ? 'numbers_take_free'.tr
                    : 'numbers_buy'.tr,
                onTap: () {
                  Get.back();
                  sendAction(NumbersBuy(item));
                },
              ),
              SizedBox(height: 10.dp),
              SecondaryButton(
                text: 'cancel'.tr,
                onTap: () => Get.back(),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Future<void> _buy(CatalogNumber item) async {
    if (state.purchasing.value) return;
    state.purchasing.value = true;
    try {
      if (item.group.isFree) {
        final result =
            await Get.find<NumbersRepository>().purchaseFree(item.number);
        await result.when(
          success: (data) async {
            final map = asMap(data);
            if (map != null) {
              await SessionStore.saveUser(Map<String, dynamic>.from(map));
            }
            showAppMessage(
              'numbers_buy_success'.trParams({
                'number': formatNumber(item.number),
              }),
            );
            await _loadMine();
            await _loadCatalog(reset: true);
          },
          failure: (e) async => showAppError(e),
        );
        return;
      }

      // Reserve then checkout
      final reserve =
          await Get.find<NumbersRepository>().reserve(item.number);
      final reserveOk = reserve.errorOrNull == null;
      if (!reserveOk) {
        showAppError(reserve.errorOrNull);
        return;
      }

      final payments = Get.find<PaymentRepository>();
      final checkout = await payments.checkoutNumber(number: item.number);
      await checkout.when(
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
            }
            if (id is num) {
              _pendingPaymentId = id.toInt();
              state.awaitingPayment.value = true;
              _startPollLoop();
              showAppMessage('numbers_checkout_opened'.tr);
            }
            return;
          }

          if (id is num && (kDebugMode || mockConfirm == true)) {
            final confirm = await payments.confirmMock(id.toInt());
            await confirm.when(
              success: (cdata) async {
                final map = asMap(cdata);
                final user = map?['user'];
                if (user is Map) {
                  await SessionStore.saveUser(
                    Map<String, dynamic>.from(user),
                  );
                }
                showAppMessage(
                  'numbers_buy_success'.trParams({
                    'number': formatNumber(item.number),
                  }),
                );
                await _loadMine();
                await _loadCatalog(reset: true);
              },
              failure: (e) async => showAppError(e),
            );
          } else {
            showAppMessage('numbers_checkout_opened'.tr);
          }
        },
        failure: (e) async => showAppError(e),
      );
    } finally {
      state.purchasing.value = false;
    }
  }

  void _startPollLoop() {
    _pollTimer?.cancel();
    var attempts = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      attempts++;
      final done = await _pollPendingPayment(showWaiting: false);
      if (done || attempts >= 40) {
        _pollTimer?.cancel();
        if (!done && attempts >= 40) {
          showAppMessage('numbers_payment_check_hint'.tr);
        }
      }
    });
  }

  Future<bool> _pollPendingPayment({required bool showWaiting}) async {
    final id = _pendingPaymentId;
    if (id == null) {
      if (showWaiting) showAppMessage('numbers_payment_check_hint'.tr);
      return true;
    }
    final payments = Get.find<PaymentRepository>();
    final result = await payments.getPayment(id);
    var resolved = false;
    result.when(
      success: (data) {
        final map = asMap(data);
        final status = map?['status']?.toString().toLowerCase();
        if (status == 'paid' ||
            status == 'succeeded' ||
            status == 'completed') {
          resolved = true;
          _pendingPaymentId = null;
          state.awaitingPayment.value = false;
          _pollTimer?.cancel();
          showAppMessage('numbers_payment_success'.tr);
          unawaited(_refreshUser());
          unawaited(_loadMine());
          unawaited(_loadCatalog(reset: true));
        } else if (status == 'failed' ||
            status == 'canceled' ||
            status == 'cancelled') {
          resolved = true;
          _pendingPaymentId = null;
          state.awaitingPayment.value = false;
          _pollTimer?.cancel();
          showAppMessage('numbers_payment_failed'.tr);
        } else if (showWaiting) {
          showAppMessage('numbers_payment_pending'.tr);
        }
      },
      failure: (e) {
        if (showWaiting) showAppError(e);
      },
    );
    return resolved;
  }

  Future<void> _refreshUser() async {
    final result = await Get.find<ProfileRepository>().getMe();
    result.when(
      success: (data) {
        final map = asMap(data);
        if (map != null) {
          unawaited(SessionStore.saveUser(Map<String, dynamic>.from(map)));
        }
      },
      failure: (_) {},
    );
  }
}
