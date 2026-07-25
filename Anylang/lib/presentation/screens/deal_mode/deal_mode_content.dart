import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../ui/app_loading.dart';
import '../../ui/app_top_bar.dart';
import '../../ui/buttons/primary_button.dart';
import '../../ui/buttons/rich_button.dart';
import '../../ui/gradient_background.dart';
import '../../ui/keyboard_aware_scroll.dart';
import '../../ui/theme/colors.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import 'deal_mode_action.dart';
import 'deal_mode_models.dart';
import 'deal_mode_state.dart';

class DealModeContent extends ScreenContent<DealModeState> {
  @override
  Widget build(
    BuildContext context,
    DealModeState state,
    void Function(MyAction action) sendAction,
  ) {
    final c = context.appColors;

    return GradientBackground(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.dp, 4.dp, 8.dp, 0),
              child: AppTopBar(
                title: 'deal_mode_title'.tr,
                onBack: () => sendAction(Back()),
                trailing: Obx(() {
                  final deal = state.deal.value;
                  if (deal == null || deal.status == 'closed') {
                    return const SizedBox.shrink();
                  }
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => sendAction(DealModeClose()),
                      borderRadius: BorderRadius.circular(10.dp),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.dp,
                          vertical: 8.dp,
                        ),
                        child: Text(
                          'deal_mode_close'.tr,
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Expanded(
              child: Obx(() {
                if (state.loading.value) {
                  return const Center(child: AppLoading());
                }
                final deal = state.deal.value;
                if (deal == null) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.dp),
                      child: Text(
                        'deal_mode_empty'.tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                  );
                }
                return KeyboardAwareScrollView(
                  padding: EdgeInsets.fromLTRB(16.dp, 8.dp, 16.dp, 28.dp),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _StatusBanner(deal: deal),
                      SizedBox(height: 10.dp),
                      Text(
                        'deal_mode_hint'.tr,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 13.sp,
                          height: 1.35,
                        ),
                      ),
                      SizedBox(height: 16.dp),
                      _sectionLabel(c, '📦 ${'deal_mode_product'.tr}'),
                      SizedBox(height: 6.dp),
                      _field(c, state.productCtrl, 'deal_mode_product_hint'.tr),
                      SizedBox(height: 12.dp),
                      _sectionLabel(c, '💵 ${'deal_mode_price'.tr}'),
                      SizedBox(height: 6.dp),
                      Row(
                        children: [
                          Expanded(
                            child: _field(
                              c,
                              state.priceCtrl,
                              'deal_mode_price_hint'.tr,
                              keyboard: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.,]'),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 8.dp),
                          for (final cur in const ['USD', 'UZS', 'EUR']) ...[
                            if (cur != 'USD') SizedBox(width: 6.dp),
                            _currencyChip(c, state, sendAction, cur),
                          ],
                        ],
                      ),
                      SizedBox(height: 12.dp),
                      _sectionLabel(c, '🔢 ${'deal_mode_quantity'.tr}'),
                      SizedBox(height: 6.dp),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _field(
                              c,
                              state.quantityCtrl,
                              'deal_mode_quantity_hint'.tr,
                            ),
                          ),
                          SizedBox(width: 8.dp),
                          Expanded(
                            child: _field(
                              c,
                              state.unitCtrl,
                              'deal_mode_unit_hint'.tr,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.dp),
                      _sectionLabel(c, '📅 ${'deal_mode_delivery'.tr}'),
                      SizedBox(height: 6.dp),
                      _field(
                        c,
                        state.deliveryCtrl,
                        'deal_mode_delivery_hint'.tr,
                      ),
                      SizedBox(height: 12.dp),
                      _sectionLabel(c, '💳 ${'deal_mode_payment'.tr}'),
                      SizedBox(height: 6.dp),
                      _field(
                        c,
                        state.paymentCtrl,
                        'deal_mode_payment_hint'.tr,
                        maxLines: 2,
                      ),
                      SizedBox(height: 18.dp),
                      _sectionLabel(c, '📄 ${'deal_mode_documents'.tr}'),
                      SizedBox(height: 8.dp),
                      if (deal.documents.isEmpty)
                        Text(
                          'deal_mode_documents_empty'.tr,
                          style: TextStyle(
                            color: c.textFaint,
                            fontSize: 12.sp,
                          ),
                        )
                      else
                        ...deal.documents.map(
                          (d) => Padding(
                            padding: EdgeInsets.only(bottom: 8.dp),
                            child: _DocTile(
                              title: d.title,
                              kind: d.kind,
                              onRemove: () =>
                                  sendAction(DealModeDetachDoc(d.messageId)),
                            ),
                          ),
                        ),
                      if (state.candidates.isNotEmpty) ...[
                        SizedBox(height: 10.dp),
                        Text(
                          'deal_mode_attach_from_chat'.tr,
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 8.dp),
                        ..._attachCandidates(state, sendAction, c),
                      ],
                      SizedBox(height: 20.dp),
                      Obx(() {
                        final busy = state.saving.value;
                        return PrimaryButton(
                          text: 'deal_mode_save'.tr,
                          isLoading: busy,
                          enabled: !busy,
                          onTap: () => sendAction(DealModeSave()),
                        );
                      }),
                      SizedBox(height: 10.dp),
                      if (!deal.viewerAccepted && deal.status != 'agreed')
                        RichButton(
                          text: 'deal_mode_accept'.tr,
                          onTap: () => sendAction(DealModeAccept()),
                          enabled: !state.saving.value,
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(14.dp),
                            border: Border.all(color: c.accent),
                          ),
                          textStyle: TextStyle(
                            color: c.accent,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      else if (deal.status == 'agreed')
                        Container(
                          padding: EdgeInsets.all(14.dp),
                          decoration: BoxDecoration(
                            color: c.accentSoft,
                            borderRadius: BorderRadius.circular(14.dp),
                          ),
                          child: Text(
                            'deal_mode_agreed'.tr,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: c.accent,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      else
                        Text(
                          'deal_mode_waiting_peer'.tr,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 13.sp,
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _attachCandidates(
    DealModeState state,
    void Function(MyAction) sendAction,
    AppColors c,
  ) {
    final attached = {
      for (final d in state.deal.value?.documents ?? const <DealDocument>[])
        d.messageId,
    };
    final out = <Widget>[];
    var shown = 0;
    for (final cand in state.candidates) {
      if (attached.contains(cand.messageId)) continue;
      if (shown >= 6) break;
      shown++;
      out.add(
        Padding(
          padding: EdgeInsets.only(bottom: 8.dp),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => sendAction(DealModeAttachDoc(cand)),
              borderRadius: BorderRadius.circular(12.dp),
              child: Ink(
                padding: EdgeInsets.symmetric(horizontal: 12.dp, vertical: 10.dp),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(12.dp),
                  border: Border.all(color: c.surfaceBorder),
                ),
                child: Row(
                  children: [
                    Text(_kindEmoji(cand.kind), style: TextStyle(fontSize: 16.sp)),
                    SizedBox(width: 10.dp),
                    Expanded(
                      child: Text(
                        cand.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(Icons.add_rounded, color: c.accent, size: 20.dp),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return out;
  }

  Widget _currencyChip(
    AppColors c,
    DealModeState state,
    void Function(MyAction) sendAction,
    String cur,
  ) {
    return Obx(() {
      final selected = state.currency.value == cur;
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => sendAction(DealModePickCurrency(cur)),
          borderRadius: BorderRadius.circular(10.dp),
          child: Ink(
            padding: EdgeInsets.symmetric(horizontal: 10.dp, vertical: 12.dp),
            decoration: BoxDecoration(
              color: selected ? c.accentSoft : c.surface,
              borderRadius: BorderRadius.circular(10.dp),
              border: Border.all(
                color: selected ? c.accent : c.surfaceBorder,
              ),
            ),
            child: Text(
              cur,
              style: TextStyle(
                color: selected ? c.accent : c.textSecondary,
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _sectionLabel(AppColors c, String text) {
    return Text(
      text,
      style: TextStyle(
        color: c.textSecondary,
        fontSize: 12.sp,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _field(
    AppColors c,
    TextEditingController ctrl,
    String hint, {
    int maxLines = 1,
    TextInputType? keyboard,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboard,
      inputFormatters: inputFormatters,
      style: TextStyle(color: c.textPrimary, fontSize: 15.sp),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.textFaint, fontSize: 14.sp),
        filled: true,
        fillColor: c.surface,
        contentPadding: EdgeInsets.symmetric(horizontal: 14.dp, vertical: 12.dp),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.dp),
          borderSide: BorderSide(color: c.surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.dp),
          borderSide: BorderSide(color: c.surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.dp),
          borderSide: BorderSide(color: c.accent),
        ),
      ),
    );
  }
}

String _kindEmoji(String kind) {
  switch (kind) {
    case 'invoice':
      return '🧾';
    case 'product':
      return '📦';
    case 'catalog':
      return '📚';
    case 'image':
      return '🖼️';
    default:
      return '📄';
  }
}

class _StatusBanner extends StatelessWidget {
  final DealData deal;

  const _StatusBanner({required this.deal});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final agreed = deal.status == 'agreed';
    return Container(
      padding: EdgeInsets.all(12.dp),
      decoration: BoxDecoration(
        color: agreed ? c.accentSoft : c.surface,
        borderRadius: BorderRadius.circular(14.dp),
        border: Border.all(
          color: agreed ? c.accent.withValues(alpha: 0.4) : c.surfaceBorder,
        ),
      ),
      child: Row(
        children: [
          Text(agreed ? '✅' : '🤝', style: TextStyle(fontSize: 18.sp)),
          SizedBox(width: 10.dp),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  agreed ? 'deal_mode_status_agreed'.tr : 'deal_mode_status_open'.tr,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2.dp),
                Text(
                  'deal_mode_accept_meta'.trParams({
                    'n': '${deal.acceptedCount}',
                    'v': '${deal.version}',
                  }),
                  style: TextStyle(color: c.textSecondary, fontSize: 11.sp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  final String title;
  final String kind;
  final VoidCallback onRemove;

  const _DocTile({
    required this.title,
    required this.kind,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.dp, vertical: 10.dp),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12.dp),
        border: Border.all(color: c.surfaceBorder),
      ),
      child: Row(
        children: [
          Text(_kindEmoji(kind), style: TextStyle(fontSize: 16.sp)),
          SizedBox(width: 10.dp),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(8.dp),
              child: Padding(
                padding: EdgeInsets.all(6.dp),
                child: Icon(Icons.close_rounded, size: 18.dp, color: c.textFaint),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
