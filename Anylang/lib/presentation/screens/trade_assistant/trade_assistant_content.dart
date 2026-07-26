import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../ui/buttons/my_icon_button.dart';
import '../../ui/chat_wallpaper_background.dart';
import '../../ui/frosted_bar.dart';
import '../../ui/profile_avatar.dart';
import '../../ui/theme/colors.dart';
import '../../ui/theme/gradients.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import 'trade_assistant_action.dart';
import 'trade_assistant_message.dart';
import 'trade_assistant_state.dart';

class TradeAssistantContent extends ScreenContent<TradeAssistantState> {
  late final TextEditingController _composer;
  late final ScrollController _scroll;

  @override
  void initContent() {
    _composer = TextEditingController();
    _scroll = ScrollController();
  }

  @override
  void onClose() {
    _composer.dispose();
    _scroll.dispose();
  }

  @override
  Widget build(
    BuildContext context,
    TradeAssistantState state,
    FutureOr<void> Function(MyAction action) sendAction,
  ) {
    final c = context.appColors;

    return ChatWallpaperBackground(
      child: Column(
        children: [
          _appBar(c, state, sendAction),
          Expanded(
            child: Obx(() {
              final items = state.messages.toList();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!_scroll.hasClients) return;
                _scroll.jumpTo(_scroll.position.maxScrollExtent);
              });
              return ListView.builder(
                controller: _scroll,
                padding: EdgeInsets.fromLTRB(14.dp, 12.dp, 14.dp, 12.dp),
                itemCount: items.length,
                itemBuilder: (_, i) => _bubble(c, items[i], sendAction),
              );
            }),
          ),
          Obx(() {
            final err = state.error.value;
            if (err.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: EdgeInsets.fromLTRB(16.dp, 0, 16.dp, 6.dp),
              child: Text(
                err,
                style: TextStyle(
                  color: kListenRed,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }),
          _composerBar(c, state, sendAction),
        ],
      ),
    );
  }

  Widget _appBar(
    AppColors c,
    TradeAssistantState state,
    void Function(MyAction) sendAction,
  ) {
    return FrostedBar(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(6.dp, 6.dp, 12.dp, 10.dp),
          child: Row(
            children: [
              MyIconButton(
                onClick: () => sendAction(Back()),
                icon: Icons.arrow_back_ios_new_rounded,
                iconColor: c.accentText,
                iconSize: 18.dp,
                backgroundColor: Colors.transparent,
                borderRadius: 12.dp,
                padding: EdgeInsets.all(8.dp),
              ),
              ProfileAvatar(
                initial: 'AI',
                gradient: limeButtonGradient,
                size: 40,
                shape: ProfileAvatarShape.circle,
              ),
              SizedBox(width: 10.dp),
              Expanded(
                child: Obx(() {
                  final company = state.companyName.value;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'trade_ai_title'.tr,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2.dp),
                      Text(
                        (company != null && company.isNotEmpty)
                            ? company
                            : 'trade_ai_status'.tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bubble(
    AppColors c,
    TradeAssistantMessage m,
    void Function(MyAction) sendAction,
  ) {
    final out = m.isOutgoing;
    final bg = out ? c.accent : c.surface;
    final fg = out ? c.onAccent : c.textPrimary;

    return Align(
      alignment: out ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: SizeController.screenWidth * 0.86),
        child: Container(
          margin: EdgeInsets.only(bottom: 10.dp),
          padding: EdgeInsets.fromLTRB(12.dp, 10.dp, 12.dp, 10.dp),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16.dp),
              topRight: Radius.circular(16.dp),
              bottomLeft: Radius.circular(out ? 16.dp : 5.dp),
              bottomRight: Radius.circular(out ? 5.dp : 16.dp),
            ),
            border: out
                ? null
                : Border.all(color: c.surfaceBorder, width: 0.7),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                m.text,
                style: TextStyle(
                  color: fg.withValues(alpha: m.pending ? 0.7 : 1),
                  fontSize: 14.sp,
                  height: 1.35,
                  fontStyle: m.pending ? FontStyle.italic : FontStyle.normal,
                  fontWeight: out ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              if (m.products.isNotEmpty) ...[
                SizedBox(height: 10.dp),
                ...m.products.map((p) => _productChip(c, p, sendAction)),
              ],
              if (m.sellers.isNotEmpty) ...[
                SizedBox(height: 8.dp),
                Text(
                  'trade_ai_sellers'.tr,
                  style: TextStyle(
                    color: c.accentText,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6.dp),
                ...m.sellers.map((s) => _sellerChip(c, s, sendAction)),
              ],
              if (m.nextQuestions.isNotEmpty) ...[
                SizedBox(height: 10.dp),
                Wrap(
                  spacing: 6.dp,
                  runSpacing: 6.dp,
                  children: m.nextQuestions
                      .map(
                        (q) => Material(
                          color: c.accentSoft,
                          borderRadius: BorderRadius.circular(99.dp),
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              sendAction(TradeUseSuggestion(q));
                            },
                            borderRadius: BorderRadius.circular(99.dp),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10.dp,
                                vertical: 7.dp,
                              ),
                              child: Text(
                                q,
                                style: TextStyle(
                                  color: c.accentText,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _productChip(
    AppColors c,
    TradeAssistantMatchProduct p,
    void Function(MyAction) sendAction,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.dp),
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(12.dp),
        child: InkWell(
          onTap: () => sendAction(TradeTapProduct(p)),
          borderRadius: BorderRadius.circular(12.dp),
          child: Padding(
            padding: EdgeInsets.all(10.dp),
            child: Row(
              children: [
                Icon(Icons.inventory_2_outlined, size: 18.dp, color: c.accentText),
                SizedBox(width: 8.dp),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (p.priceLabel.isNotEmpty ||
                          (p.sellerName ?? '').isNotEmpty)
                        Text(
                          [
                            if (p.priceLabel.isNotEmpty) p.priceLabel,
                            if ((p.sellerName ?? '').isNotEmpty) p.sellerName!,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 11.sp,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: c.textFaint, size: 18.dp),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sellerChip(
    AppColors c,
    TradeAssistantMatchSeller s,
    void Function(MyAction) sendAction,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.dp),
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(12.dp),
        child: InkWell(
          onTap: () => sendAction(TradeTapSeller(s)),
          borderRadius: BorderRadius.circular(12.dp),
          child: Padding(
            padding: EdgeInsets.all(10.dp),
            child: Row(
              children: [
                Icon(Icons.factory_outlined, size: 18.dp, color: c.accentText),
                SizedBox(width: 8.dp),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              s.companyName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (s.verified) ...[
                            SizedBox(width: 4.dp),
                            Icon(Icons.verified_rounded,
                                size: 14.dp, color: c.accent),
                          ],
                        ],
                      ),
                      Text(
                        [
                          if ((s.country ?? '').isNotEmpty) s.country!,
                          if ((s.businessRole ?? '').isNotEmpty)
                            'business_role_${s.businessRole}'.tr,
                          'trade_ai_products_n'.trParams({'n': '${s.productsCount}'}),
                        ].where((e) => e.trim().isNotEmpty).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 11.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: c.textFaint, size: 18.dp),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _composerBar(
    AppColors c,
    TradeAssistantState state,
    void Function(MyAction) sendAction,
  ) {
    return FrostedBar(
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12.dp, 8.dp, 12.dp, 12.dp),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  constraints: BoxConstraints(minHeight: 44.dp),
                  padding: EdgeInsets.symmetric(horizontal: 14.dp),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border.all(color: c.surfaceBorder, width: 0.7),
                    borderRadius: BorderRadius.circular(22.dp),
                  ),
                  child: TextField(
                    controller: _composer,
                    minLines: 1,
                    maxLines: 4,
                    onChanged: (v) => sendAction(TradeComposerChanged(v)),
                    cursorColor: c.accent,
                    style: TextStyle(color: c.textPrimary, fontSize: 15.sp),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 11.dp),
                      hintText: 'trade_ai_hint'.tr,
                      hintStyle: TextStyle(color: c.textFaint, fontSize: 14.sp),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8.dp),
              Obx(() {
                final can = state.showSend.value && !state.sending.value;
                return MyIconButton(
                  onClick: can
                      ? () {
                          final text = _composer.text;
                          _composer.clear();
                          sendAction(TradeComposerChanged(''));
                          sendAction(TradeSend(text));
                        }
                      : () {},
                  icon: Icons.send_rounded,
                  iconColor: c.onAccent,
                  iconSize: 20.dp,
                  backgroundGradient: can ? limeButtonGradient : null,
                  backgroundColor: can ? null : c.surface,
                  borderRadius: 22.dp,
                  padding: EdgeInsets.all(11.dp),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
