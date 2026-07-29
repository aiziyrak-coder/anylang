import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../screens/products/products_action.dart';
import '../screens/products/products_state.dart';
import '../ui/buttons/primary_button.dart';
import '../ui/market_promo_banner.dart';
import '../ui/theme/colors.dart';
import '../utils/screen_options/my_action.dart';
import '../utils/size_controller.dart';

/// Bozor — banner pager + tezkor filterlar o‘rniga bitta filter sheet.
/// Tanlovlar draft’da; «Saralash» bosilganda apply + dismiss.
Future<void> showProductsFiltersBottomSheet(
  BuildContext context, {
  required ProductsState state,
  required FutureOr<void> Function(MyAction action) sendAction,
}) {
  final c = context.appColors;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return _ProductsFiltersSheet(
        appColors: c,
        state: state,
        sendAction: sendAction,
      );
    },
  );
}

class _ProductsFiltersSheet extends StatefulWidget {
  final AppColors appColors;
  final ProductsState state;
  final FutureOr<void> Function(MyAction action) sendAction;

  const _ProductsFiltersSheet({
    required this.appColors,
    required this.state,
    required this.sendAction,
  });

  @override
  State<_ProductsFiltersSheet> createState() => _ProductsFiltersSheetState();
}

class _ProductsFiltersSheetState extends State<_ProductsFiltersSheet> {
  String? _promoId;
  bool _verifiedOnly = false;
  bool _factoryOnly = false;
  bool _trendOnly = false;
  bool _readyStockOnly = false;
  bool _newOnly = false;
  bool _freeShippingOnly = false;
  bool _premiumSellerOnly = false;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    final s = widget.state;
    _promoId = s.selectedPromoId.value;
    _verifiedOnly = s.verifiedOnly.value;
    _factoryOnly = s.isFactoryFilter;
    _trendOnly = s.trendOnly.value;
    _readyStockOnly = s.readyStockOnly.value;
    _newOnly = s.newOnly.value;
    _freeShippingOnly = s.freeShippingOnly.value;
    _premiumSellerOnly = s.premiumSellerOnly.value;
  }

  bool get _hasDraftFilters =>
      (_promoId != null && _promoId!.isNotEmpty) ||
      _verifiedOnly ||
      _factoryOnly ||
      _trendOnly ||
      _readyStockOnly ||
      _newOnly ||
      _freeShippingOnly ||
      _premiumSellerOnly;

  void _clearDraft() {
    setState(() {
      _promoId = null;
      _verifiedOnly = false;
      _factoryOnly = false;
      _trendOnly = false;
      _readyStockOnly = false;
      _newOnly = false;
      _freeShippingOnly = false;
      _premiumSellerOnly = false;
    });
  }

  void _selectPromo(String id) {
    setState(() {
      if (_promoId == id) {
        _promoId = null;
      } else {
        _promoId = id;
        // Kolleksiya tanlanganda tezkor filterlar bilan chalkashmasin —
        // promo o‘zi asosiy filtrlarni belgilaydi; chip’lar saqlanadi.
      }
    });
  }

  Future<void> _apply() async {
    if (_applying) return;
    setState(() => _applying = true);
    HapticFeedback.mediumImpact();
    try {
      await widget.sendAction(
        ProductsApplySheetFilters(
          promoId: _promoId,
          verifiedOnly: _verifiedOnly,
          factoryOnly: _factoryOnly,
          trendOnly: _trendOnly,
          readyStockOnly: _readyStockOnly,
          newOnly: _newOnly,
          freeShippingOnly: _freeShippingOnly,
          premiumSellerOnly: _premiumSellerOnly,
        ),
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.appColors;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: c.isDark ? const Color(0xFF0C2136) : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.dp)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.dp, 12.dp, 20.dp, 20.dp),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44.dp,
                  height: 5.dp,
                  decoration: BoxDecoration(
                    color: c.outline,
                    borderRadius: BorderRadius.circular(5.dp),
                  ),
                ),
              ),
              SizedBox(height: 14.dp),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'products_filters_title'.tr,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_hasDraftFilters)
                    TextButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        _clearDraft();
                      },
                      child: Text(
                        'products_filter_clear'.tr,
                        style: TextStyle(
                          color: c.accent,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 8.dp),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'products_filters_collections'.tr,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 10.dp),
                      Column(
                        children: [
                          for (final slide in MarketPromoBanner.slides) ...[
                            _CollectionTile(
                              emoji: slide.emoji,
                              title: slide.titleKey.tr,
                              selected: _promoId == slide.id,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                _selectPromo(slide.id);
                              },
                            ),
                            SizedBox(height: 8.dp),
                          ],
                        ],
                      ),
                      SizedBox(height: 16.dp),
                      Text(
                        'products_filters_quick'.tr,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 10.dp),
                      Wrap(
                        spacing: 8.dp,
                        runSpacing: 8.dp,
                        children: [
                          _FilterChip(
                            c: c,
                            label: 'products_tezkor_verified'.tr,
                            selected: _verifiedOnly,
                            onTap: () => setState(
                              () => _verifiedOnly = !_verifiedOnly,
                            ),
                          ),
                          _FilterChip(
                            c: c,
                            label: 'products_tezkor_factory'.tr,
                            selected: _factoryOnly,
                            onTap: () =>
                                setState(() => _factoryOnly = !_factoryOnly),
                          ),
                          _FilterChip(
                            c: c,
                            label: 'products_tezkor_trend'.tr,
                            selected: _trendOnly,
                            onTap: () =>
                                setState(() => _trendOnly = !_trendOnly),
                          ),
                          _FilterChip(
                            c: c,
                            label: 'products_tezkor_ready_stock'.tr,
                            selected: _readyStockOnly,
                            onTap: () => setState(
                              () => _readyStockOnly = !_readyStockOnly,
                            ),
                          ),
                          _FilterChip(
                            c: c,
                            label: 'products_tezkor_new'.tr,
                            selected: _newOnly,
                            onTap: () => setState(() => _newOnly = !_newOnly),
                          ),
                          _FilterChip(
                            c: c,
                            label: 'products_tezkor_free_shipping'.tr,
                            selected: _freeShippingOnly,
                            onTap: () => setState(
                              () => _freeShippingOnly = !_freeShippingOnly,
                            ),
                          ),
                          _FilterChip(
                            c: c,
                            label: 'products_tezkor_premium'.tr,
                            selected: _premiumSellerOnly,
                            onTap: () => setState(
                              () =>
                                  _premiumSellerOnly = !_premiumSellerOnly,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.dp),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 12.dp),
              PrimaryButton(
                text: 'products_filters_apply'.tr,
                onTap: _apply,
                isLoading: _applying,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollectionTile extends StatelessWidget {
  final String emoji;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _CollectionTile({
    required this.emoji,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final radius = BorderRadius.circular(14.dp);
    return Material(
      color: selected ? c.accentSoft : c.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.dp, vertical: 12.dp),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: selected ? c.accent : c.surfaceBorder,
              width: selected ? 1.4 : 0.8,
            ),
          ),
          child: Row(
            children: [
              Text(emoji, style: TextStyle(fontSize: 22.sp)),
              SizedBox(width: 12.dp),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: selected ? c.accentText : c.textPrimary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: c.accent, size: 22.dp)
              else
                Icon(
                  Icons.circle_outlined,
                  color: c.textFaint,
                  size: 20.dp,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final AppColors c;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const _FilterChip({
    required this.c,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? c.accent : c.surface,
      borderRadius: BorderRadius.circular(99.dp),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(99.dp),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.dp, vertical: 8.dp),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99.dp),
            border: Border.all(color: selected ? c.accent : c.surfaceBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14.dp,
                  color: selected ? c.onAccent : c.textSecondary,
                ),
                SizedBox(width: 6.dp),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? c.onAccent : c.textPrimary,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (selected) ...[
                SizedBox(width: 4.dp),
                Icon(Icons.check_rounded, size: 14.dp, color: c.onAccent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
