import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/core/mappers.dart';
import '../../ui/app_empty_state.dart';
import '../../ui/app_loading.dart';
import '../../ui/app_top_bar.dart';
import '../../ui/buttons/primary_button.dart';
import '../../ui/buttons/secondary_button.dart';
import '../../ui/gradient_background.dart';
import '../../ui/theme/colors.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import 'number_models.dart';
import 'numbers_action.dart';
import 'numbers_state.dart';

class NumbersContent extends ScreenContent<NumbersState> {
  NumbersContent() : super(color: Colors.transparent);

  @override
  Widget build(
    BuildContext context,
    NumbersState state,
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
                title: 'numbers_title'.tr,
                onBack: () => sendAction(NumbersBack()),
              ),
            ),
            Expanded(
              child: Obx(() {
                if (state.loading.value && state.my.value == null) {
                  return const AppLoading();
                }
                if (state.error.value != null && state.my.value == null) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 28.dp),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppEmptyState(
                            icon: Icons.dialpad_rounded,
                            title: 'numbers_load_failed'.tr,
                            subtitle: state.error.value,
                          ),
                          SizedBox(height: 16.dp),
                          SecondaryButton(
                            text: 'common_retry'.tr,
                            onTap: () => sendAction(NumbersRetry()),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => sendAction(NumbersRetry()),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: _myCard(c, state, sendAction)),
                      SliverToBoxAdapter(child: _filters(c, state, sendAction)),
                      if (state.catalogLoading.value && state.items.isEmpty)
                        const SliverFillRemaining(child: AppLoading())
                      else if (state.items.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: AppEmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'numbers_empty'.tr,
                            subtitle: 'numbers_empty_hint'.tr,
                          ),
                        )
                      else
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(16.dp, 0, 16.dp, 24.dp),
                          sliver: SliverList.separated(
                            itemCount:
                                state.items.length + (state.hasMore.value ? 1 : 0),
                            separatorBuilder: (_, __) => SizedBox(height: 10.dp),
                            itemBuilder: (_, i) {
                              if (i >= state.items.length) {
                                return Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8.dp),
                                  child: Center(
                                    child: TextButton(
                                      onPressed: () =>
                                          sendAction(NumbersLoadMore()),
                                      child: Text('numbers_load_more'.tr),
                                    ),
                                  ),
                                );
                              }
                              return _catalogTile(
                                c,
                                state.items[i],
                                () => sendAction(NumbersOpenItem(state.items[i])),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ),
            Obx(() {
              if (!state.awaitingPayment.value) return const SizedBox.shrink();
              return Padding(
                padding: EdgeInsets.fromLTRB(16.dp, 0, 16.dp, 12.dp),
                child: SecondaryButton(
                  text: 'numbers_check_payment'.tr,
                  onTap: () => sendAction(NumbersCheckPayment()),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _myCard(
    AppColors c,
    NumbersState state,
    void Function(MyAction) sendAction,
  ) {
    final mine = state.my.value;
    final number = mine?.number ?? '';
    final groupName = mine?.group?.name;
    final canSwap = mine?.canChangeFree ?? true;
    final cooldownDays = mine == null
        ? 0
        : (mine.cooldownSeconds / 86400).ceil().clamp(0, 90);

    return Padding(
      padding: EdgeInsets.fromLTRB(16.dp, 12.dp, 16.dp, 8.dp),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(18.dp),
        decoration: BoxDecoration(
          color: c.isDark ? const Color(0x99152A42) : const Color(0xCCFFFFFF),
          borderRadius: BorderRadius.circular(20.dp),
          border: Border.all(color: c.surfaceBorder, width: 0.7),
          boxShadow: c.glassShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'numbers_my_label'.tr,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8.dp),
            Text(
              number.isEmpty ? '—' : formatNumber(number),
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 30.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
            if (groupName != null && groupName.isNotEmpty) ...[
              SizedBox(height: 6.dp),
              Text(
                groupName,
                style: TextStyle(
                  color: c.accentText,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            SizedBox(height: 14.dp),
            Obx(() {
              final busy = state.purchasing.value;
              return PrimaryButton(
                text: canSwap
                    ? 'numbers_swap_free'.tr
                    : 'numbers_cooldown'.trParams({'days': '$cooldownDays'}),
                isLoading: busy,
                enabled: canSwap && !busy,
                onTap: () => sendAction(NumbersRandomSwap()),
              );
            }),
            SizedBox(height: 8.dp),
            Text(
              'numbers_swap_hint'.tr,
              style: TextStyle(
                color: c.textFaint,
                fontSize: 12.sp,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filters(
    AppColors c,
    NumbersState state,
    void Function(MyAction) sendAction,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.dp, 8.dp, 16.dp, 12.dp),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'numbers_shop'.tr,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4.dp),
          Obx(() => Text(
                'numbers_total'.trParams({'count': '${state.total.value}'}),
                style: TextStyle(color: c.textSecondary, fontSize: 12.sp),
              )),
          SizedBox(height: 12.dp),
          TextField(
            onChanged: (v) => sendAction(NumbersSearch(v)),
            keyboardType: TextInputType.number,
            style: TextStyle(color: c.textPrimary, fontSize: 15.sp),
            decoration: InputDecoration(
              hintText: 'numbers_search_hint'.tr,
              hintStyle: TextStyle(color: c.textFaint, fontSize: 14.sp),
              prefixIcon: Icon(Icons.search_rounded, color: c.textSecondary),
              filled: true,
              fillColor:
                  c.isDark ? const Color(0x66152A42) : const Color(0xEEFFFFFF),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.dp),
                borderSide: BorderSide(color: c.surfaceBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.dp),
                borderSide: BorderSide(color: c.surfaceBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.dp),
                borderSide: BorderSide(color: c.accent, width: 1.2),
              ),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12.dp, vertical: 12.dp),
            ),
          ),
          SizedBox(height: 12.dp),
          SizedBox(
            height: 38.dp,
            child: Obx(() {
              final selected = state.selectedGroupId.value;
              return ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _chip(
                    c,
                    label: 'numbers_all'.tr,
                    selected: selected == null,
                    onTap: () => sendAction(NumbersSelectGroup(null)),
                  ),
                  ...state.groups.map(
                    (g) => Padding(
                      padding: EdgeInsets.only(left: 8.dp),
                      child: _chip(
                        c,
                        label: '${g.name} · ${g.priceLabel}',
                        selected: selected == g.id,
                        onTap: () => sendAction(NumbersSelectGroup(g.id)),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
          SizedBox(height: 10.dp),
          Row(
            children: [
              Obx(() {
                final on = state.hasBonusOnly.value;
                return FilterChip(
                  selected: on,
                  label: Text('numbers_bonus_only'.tr),
                  onSelected: (_) => sendAction(NumbersToggleBonus()),
                  selectedColor: c.accentSoft,
                  checkmarkColor: c.accentText,
                  labelStyle: TextStyle(
                    color: on ? c.accentText : c.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.sp,
                  ),
                );
              }),
              const Spacer(),
              Obx(() {
                final sort = state.sort.value;
                return PopupMenuButton<String>(
                  onSelected: (v) => sendAction(NumbersChangeSort(v)),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'price_asc',
                      child: Text('numbers_sort_price_asc'.tr),
                    ),
                    PopupMenuItem(
                      value: 'price_desc',
                      child: Text('numbers_sort_price_desc'.tr),
                    ),
                    PopupMenuItem(
                      value: 'number_asc',
                      child: Text('numbers_sort_number'.tr),
                    ),
                  ],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sort_rounded, size: 18.dp, color: c.textSecondary),
                      SizedBox(width: 4.dp),
                      Text(
                        sort == 'price_desc'
                            ? 'numbers_sort_price_desc'.tr
                            : sort == 'number_asc'
                                ? 'numbers_sort_number'.tr
                                : 'numbers_sort_price_asc'.tr,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(
    AppColors c, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? c.accent : (c.isDark ? const Color(0x66152A42) : Colors.white),
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.dp, vertical: 8.dp),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: selected ? c.accent : c.surfaceBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? c.onAccent : c.textPrimary,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _catalogTile(AppColors c, CatalogNumber item, VoidCallback onTap) {
    return Material(
      color: c.isDark ? const Color(0x99152A42) : const Color(0xCCFFFFFF),
      borderRadius: BorderRadius.circular(16.dp),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.dp),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.dp, vertical: 14.dp),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.dp),
            border: Border.all(color: c.surfaceBorder, width: 0.7),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatNumber(item.number),
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    SizedBox(height: 4.dp),
                    Text(
                      item.group.name,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (item.group.bonusPlan != null) ...[
                      SizedBox(height: 4.dp),
                      Text(
                        'numbers_bonus_short'.trParams({
                          'plan': item.group.bonusPlan!,
                        }),
                        style: TextStyle(
                          color: c.accentText,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    item.group.priceLabel,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 6.dp),
                  Icon(Icons.chevron_right_rounded, color: c.textSecondary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
