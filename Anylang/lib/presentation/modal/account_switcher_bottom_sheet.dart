import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/core/mappers.dart';
import '../../data/local/account_store.dart';
import '../../data/local/session_store.dart';
import '../../data/network/auth_repository.dart';
import '../../data/network/payment_repository.dart';
import '../../data/network/session_bootstrap.dart';
import '../../data/network/socket_service.dart';
import '../screens/login/login_payload.dart';
import '../screens/login/login_screen.dart';
import '../screens/main/main_screen.dart';
import '../screens/subscription/subscription_screen.dart';
import '../ui/buttons/primary_button.dart';
import '../ui/profile_avatar.dart';
import '../ui/theme/colors.dart';
import '../utils/app_snackbar.dart';
import '../utils/size_controller.dart';
import 'payment_confirm_bottom_sheet.dart';

/// Hisoblar ro‘yxati: almashtirish / qo‘shish / slot sotib olish.
Future<void> showAccountSwitcherBottomSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _AccountSwitcherSheet(),
  );
}

class _AccountSwitcherSheet extends StatefulWidget {
  const _AccountSwitcherSheet();

  @override
  State<_AccountSwitcherSheet> createState() => _AccountSwitcherSheetState();
}

class _AccountSwitcherSheetState extends State<_AccountSwitcherSheet> {
  bool _busy = false;

  List<AccountSlot> get _slots => AccountStore.slots();

  int? get _activeId =>
      AccountStore.activeUserId() ?? SessionStore.userId();

  Future<void> _switchTo(AccountSlot slot) async {
    if (_busy || slot.userId == _activeId) {
      if (mounted) Navigator.pop(context);
      return;
    }
    setState(() => _busy = true);
    try {
      if (SessionStore.hasSession) {
        await AccountStore.syncActiveFromSessionStore();
      }
      final ok = await AccountStore.activate(slot.userId);
      if (!ok) {
        showAppError('accounts_switch_failed'.tr);
        return;
      }
      if (Get.isRegistered<SocketService>()) {
        Get.find<SocketService>().disconnect();
      }
      await connectRealtimeIfNeeded();
      if (mounted) Navigator.pop(context);
      Get.offAll(() => MainScreen().build());
    } catch (e) {
      showAppError(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addAccount() async {
    final block = AccountStore.addBlockReason();
    if (block == AccountAddBlock.needBusiness) {
      final go = await Get.dialog<bool>(
        AlertDialog(
          title: Text('accounts_need_business_title'.tr),
          content: Text('accounts_need_business_body'.tr),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: Text('common_cancel'.tr),
            ),
            TextButton(
              onPressed: () => Get.back(result: true),
              child: Text('accounts_open_business'.tr),
            ),
          ],
        ),
      );
      if (go == true && mounted) {
        Navigator.pop(context);
        Get.to(() => SubscriptionScreen().build());
      }
      return;
    }
    if (block == AccountAddBlock.needBuySlot) {
      await _buySlot();
      return;
    }
    if (block == AccountAddBlock.atHardCap) {
      showAppMessage('accounts_hard_cap'.tr);
      return;
    }

    final restoreId = SessionStore.userId();
    if (SessionStore.hasSession) {
      await AccountStore.parkActive();
      if (Get.isRegistered<SocketService>()) {
        Get.find<SocketService>().disconnect();
      }
    }
    if (!mounted) return;
    Navigator.pop(context);
    Get.to(
      () => (LoginScreen()
            ..payload = LoginPayload(
              addAccount: true,
              restoreUserId: restoreId,
            ))
          .build(),
    );
  }

  Future<void> _buySlot() async {
    if (_busy) return;
    final active = SessionStore.user();
    if (active == null || active['is_business'] != true) {
      showAppMessage('accounts_need_business_body'.tr);
      return;
    }
    setState(() => _busy = true);
    try {
      final result =
          await Get.find<PaymentRepository>().checkoutAccountSlot();
      if (result.errorOrNull != null) {
        showAppError(result.errorOrNull);
        return;
      }
      final map = asMap(result.dataOrNull) ?? {};
      if (!mounted) return;
      final confirmed = await showPaymentConfirmBottomSheet(
        context,
        title: 'accounts_buy_slot_title'.tr,
        subtitle: 'accounts_buy_slot_body'.tr,
        amount: map['amount']?.toString() ?? '10.00',
        currency: map['currency']?.toString() ?? 'USD',
        amountBeforeTax: map['amount_before_tax']?.toString(),
        taxAmount: map['tax_amount']?.toString(),
        planLabel: 'accounts_buy_slot_title'.tr,
        ctaText: 'subscription_pay_confirm_cta'.tr,
      );
      if (confirmed != true) {
        showAppMessage('payment_confirm_later_hint'.tr);
        return;
      }
      final url = map['checkout_url']?.toString();
      final paymentId = (map['id'] as num?)?.toInt();
      if (url != null && url.isNotEmpty) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
      if (paymentId != null && map['mock_confirm'] == true) {
        await Get.find<PaymentRepository>().confirmMock(paymentId);
      }
      showAppMessage('accounts_slot_purchased'.tr);
      try {
        await AccountStore.syncActiveFromSessionStore();
      } catch (_) {}
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeSlot(AccountSlot slot) async {
    if (_busy) return;
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: Text('accounts_remove_title'.tr),
        content: Text(
          'accounts_remove_body'.trParams({'name': slot.displayName}),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('common_cancel'.tr),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text('accounts_remove'.tr),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final refresh = await AccountStore.refreshTokenOf(slot.userId);
      if (refresh != null && refresh.isNotEmpty) {
        try {
          // Serverdan ham chiqish (shu qurilma oilasi).
          await Get.find<AuthRepository>().logoutWithRefresh(refresh);
        } catch (_) {
          showAppWarning('logout_failed'.tr);
        }
      }
      await AccountStore.removeSlot(slot.userId);
      if (slot.userId == _activeId) {
        final next = AccountStore.slots();
        if (next.isNotEmpty) {
          await AccountStore.activate(next.first.userId);
          await connectRealtimeIfNeeded();
          if (mounted) Navigator.pop(context);
          Get.offAll(() => MainScreen().build());
          return;
        }
        await SessionStore.clear();
        if (mounted) Navigator.pop(context);
        Get.offAll(() => LoginScreen().build());
        return;
      }
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final slots = _slots;
    final max = AccountStore.maxAllowedSlots();
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.78,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.dp)),
        border: Border.all(color: c.surfaceBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 10.dp),
          Container(
            width: 40.dp,
            height: 4.dp,
            decoration: BoxDecoration(
              color: c.outline,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20.dp, 14.dp, 20.dp, 8.dp),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'accounts_switch_title'.tr,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${slots.length}/$max',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.fromLTRB(12.dp, 0, 12.dp, 12.dp),
              children: [
                for (final s in slots)
                  _slotTile(c, s, selected: s.userId == _activeId),
                SizedBox(height: 8.dp),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14.dp),
                    onTap: _busy ? null : _addAccount,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.dp,
                        vertical: 14.dp,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14.dp),
                        border: Border.all(
                          color: c.surfaceBorder,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42.dp,
                            height: 42.dp,
                            decoration: BoxDecoration(
                              color: c.accentSoft,
                              borderRadius: BorderRadius.circular(12.dp),
                            ),
                            child: Icon(
                              Icons.person_add_alt_1_rounded,
                              color: c.accentText,
                              size: 22.dp,
                            ),
                          ),
                          SizedBox(width: 12.dp),
                          Expanded(
                            child: Text(
                              'accounts_add'.tr,
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (AccountStore.addBlockReason() ==
                    AccountAddBlock.needBuySlot) ...[
                  SizedBox(height: 10.dp),
                  PrimaryButton(
                    text: 'accounts_buy_slot_cta'.tr,
                    onTap: _buySlot,
                    isLoading: _busy,
                  ),
                ],
                SizedBox(height: 8.dp + bottom),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _slotTile(AppColors c, AccountSlot s, {required bool selected}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.dp),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14.dp),
          onTap: _busy ? null : () => _switchTo(s),
          onLongPress: _busy ? null : () => _removeSlot(s),
          child: Container(
            padding: EdgeInsets.fromLTRB(12.dp, 10.dp, 8.dp, 10.dp),
            decoration: BoxDecoration(
              color: selected
                  ? c.accentSoft.withValues(alpha: 0.55)
                  : c.background.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(14.dp),
              border: Border.all(
                color: selected ? c.accent : c.surfaceBorder,
                width: selected ? 1.4 : 0.7,
              ),
            ),
            child: Row(
              children: [
                ProfileAvatar(
                  initial: s.displayName.isNotEmpty
                      ? s.displayName.substring(0, 1).toUpperCase()
                      : '?',
                  gradient: avatarGradientFor(s.userId),
                  imageUrl: s.avatarUrl,
                  size: 44,
                ),
                SizedBox(width: 12.dp),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2.dp),
                      Text(
                        s.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded,
                      color: c.accentText, size: 22.dp)
                else
                  IconButton(
                    tooltip: 'accounts_remove'.tr,
                    onPressed: _busy ? null : () => _removeSlot(s),
                    icon: Icon(Icons.logout_rounded,
                        size: 18.dp, color: c.textFaint),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
