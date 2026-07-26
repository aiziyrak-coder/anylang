import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/local/countries_service.dart';
import '../../../data/core/mappers.dart';
import '../../../domain/models/country_option.dart';
import '../../utils/formatters/time_formatter.dart';
import '../../utils/size_controller.dart';
import '../business_badge.dart';
import '../profile_avatar.dart';
import '../theme/colors.dart';
import '../theme/gradients.dart';

/// Tarmoq / qidiruv kartasi — ism, reyting, tip, scam ogohlantirish aniq.
class UserCardItem extends StatelessWidget {
  final String initial;
  final LinearGradient avatarGradient;
  final String? avatarUrl;
  final String name;
  final bool online;
  final DateTime? lastSeenAt;
  final String? country;
  final String? businessRole;
  final List<String> keywords;
  final bool isBusiness;
  final double? rating;
  final int reviewsCount;
  final int? trust;
  final String riskLevel;
  final bool isScammer;
  final bool verified;
  final List<String> languages;
  final VoidCallback? onTap;
  final VoidCallback? onMessage;
  final VoidCallback? onAdd;
  final VoidCallback? onCall;
  final VoidCallback? onLiveTranslate;
  final VoidCallback? onProducts;
  final VoidCallback? onProfile;
  final bool showMessage;
  final bool showAdd;
  final bool showQuickActions;
  final String? addLabel;
  final bool addEnabled;
  final int productsCount;
  final int countriesCount;

  const UserCardItem({
    super.key,
    required this.initial,
    required this.avatarGradient,
    required this.name,
    this.avatarUrl,
    this.online = false,
    this.lastSeenAt,
    this.country,
    this.businessRole,
    this.keywords = const [],
    this.isBusiness = false,
    this.rating,
    this.reviewsCount = 0,
    this.trust,
    this.riskLevel = 'none',
    this.isScammer = false,
    this.verified = false,
    this.languages = const [],
    this.productsCount = 0,
    this.countriesCount = 0,
    this.onTap,
    this.onMessage,
    this.onAdd,
    this.onCall,
    this.onLiveTranslate,
    this.onProducts,
    this.onProfile,
    this.showMessage = true,
    this.showAdd = false,
    this.showQuickActions = false,
    this.addLabel,
    this.addEnabled = true,
  });

  bool get _danger => isScammer || riskLevel == 'high';
  bool get _warn => !_danger && riskLevel == 'medium';

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final radius = BorderRadius.circular(16.dp);
    final countryLabel = _countryLabel(country);
    final activity = formatLastActivity(
      online: online,
      lastSeenAt: lastSeenAt,
    );
    final badge = resolveBusinessBadge(
      businessRole: businessRole,
      keywords: keywords,
      isBusiness: isBusiness || (businessRole ?? '').trim().isNotEmpty,
    );
    final borderColor = _danger
        ? c.danger
        : (_warn ? const Color(0xFFF59E0B) : c.surfaceBorder);
    final fill = _danger
        ? c.dangerSoft.withValues(alpha: c.isDark ? 0.35 : 0.55)
        : c.surface;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.dp, vertical: 6.dp),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? onProfile,
          borderRadius: radius,
          child: Ink(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: radius,
              border: Border.all(
                color: borderColor,
                width: (_danger || _warn) ? 1.6 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_danger || _warn)
                  _riskBanner(c),
                Padding(
                  padding: EdgeInsets.fromLTRB(12.dp, 12.dp, 12.dp, 10.dp),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProfileAvatar(
                        initial: initial,
                        gradient: avatarGradient,
                        imageUrl: avatarUrl,
                        size: 54,
                        online: online,
                      ),
                      SizedBox(width: 12.dp),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: c.textPrimary,
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w800,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8.dp),
                                _ratingBlock(c),
                              ],
                            ),
                            SizedBox(height: 6.dp),
                            Wrap(
                              spacing: 6.dp,
                              runSpacing: 6.dp,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _typeChip(c, badge),
                                _statusChip(c, activity),
                                if (verified) _verifiedChip(c),
                              ],
                            ),
                            if (countryLabel != null) ...[
                              SizedBox(height: 8.dp),
                              Text(
                                countryLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: c.textSecondary,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            if (_hasFacts) ...[
                              SizedBox(height: 8.dp),
                              _factsRow(c),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (showQuickActions) ...[
                  Divider(height: 1, thickness: 1, color: c.surfaceBorder),
                  Padding(
                    padding: EdgeInsets.fromLTRB(8.dp, 6.dp, 8.dp, 8.dp),
                    child: _quickActionsRow(c),
                  ),
                ] else if (showMessage || showAdd) ...[
                  Padding(
                    padding: EdgeInsets.fromLTRB(12.dp, 0, 12.dp, 12.dp),
                    child: Row(
                      children: [
                        if (showMessage)
                          Expanded(
                            child: _ActionChip(
                              emoji: '💬',
                              label: 'user_card_message'.tr,
                              onTap: onMessage ?? onTap,
                              primary: !showAdd,
                            ),
                          ),
                        if (showMessage && showAdd) SizedBox(width: 8.dp),
                        if (showAdd)
                          Expanded(
                            child: _ActionChip(
                              emoji: addEnabled ? '➕' : '⏳',
                              label: addLabel ?? 'user_card_add'.tr,
                              onTap: addEnabled ? onAdd : null,
                              primary: true,
                              muted: !addEnabled,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _riskBanner(AppColors c) {
    final label = _danger
        ? 'user_card_scammer'.tr
        : 'user_card_risk_medium'.tr;
    final bg = _danger ? c.danger : const Color(0xFFF59E0B);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.dp, vertical: 7.dp),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(14.5.dp)),
      ),
      child: Row(
        children: [
          Icon(
            _danger ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
            size: 16.dp,
            color: Colors.white,
          ),
          SizedBox(width: 6.dp),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ratingBlock(AppColors c) {
    if (rating == null) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8.dp, vertical: 5.dp),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(10.dp),
          border: Border.all(color: c.surfaceBorder),
        ),
        child: Text(
          'user_card_no_rating'.tr,
          style: TextStyle(
            color: c.textFaint,
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    final score = rating!.clamp(0, 5);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.dp, vertical: 5.dp),
      decoration: BoxDecoration(
        color: c.isDark
            ? const Color(0xFF3A2E12)
            : const Color(0xFFFFF8E6),
        borderRadius: BorderRadius.circular(10.dp),
        border: Border.all(
          color: c.isDark
              ? const Color(0xFF6B5200)
              : const Color(0xFFFFE08A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.star_rounded,
                size: 16.dp,
                color: const Color(0xFFF5A623),
              ),
              SizedBox(width: 3.dp),
              Text(
                score.toStringAsFixed(1),
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ],
          ),
          SizedBox(height: 2.dp),
          Text(
            reviewsCount > 0
                ? 'user_card_reviews'.trParams({'n': '$reviewsCount'})
                : 'user_card_rating_label'.tr,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeChip(AppColors c, BusinessBadgeInfo? badge) {
    final isBiz = isBusiness || badge != null;
    final label = isBiz
        ? (badge?.label ?? 'user_card_type_company'.tr)
        : 'user_card_type_person'.tr;
    final emoji = isBiz ? (badge?.emoji ?? '🏢') : '👤';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.dp, vertical: 4.dp),
      decoration: BoxDecoration(
        color: isBiz ? c.accentSoft : c.surface,
        borderRadius: BorderRadius.circular(8.dp),
        border: Border.all(
          color: isBiz ? c.accent.withValues(alpha: 0.35) : c.surfaceBorder,
        ),
      ),
      child: Text(
        '$emoji $label',
        style: TextStyle(
          color: isBiz ? c.accentText : c.textSecondary,
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _statusChip(AppColors c, String activity) {
    return Text(
      activity,
      style: TextStyle(
        color: online ? kOnline : c.textFaint,
        fontSize: 12.sp,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _verifiedChip(AppColors c) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.dp, vertical: 3.dp),
      decoration: BoxDecoration(
        color: c.accentSoft,
        borderRadius: BorderRadius.circular(8.dp),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 12.dp, color: c.accent),
          SizedBox(width: 3.dp),
          Text(
            'user_card_verified'.tr,
            style: TextStyle(
              color: c.accentText,
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  bool get _hasFacts =>
      (trust != null && trust! > 0) ||
      productsCount > 0 ||
      countriesCount > 0 ||
      formatLanguagesBadge(languages).isNotEmpty;

  Widget _factsRow(AppColors c) {
    final bits = <Widget>[];
    if (trust != null && trust! > 0) {
      bits.add(_fact(c, Icons.shield_outlined, 'user_card_trust'.trParams({
        'n': '$trust',
      })));
    }
    if (productsCount > 0) {
      bits.add(_fact(
        c,
        Icons.inventory_2_outlined,
        'user_card_stat_products'.trParams({'n': '$productsCount'}),
      ));
    }
    if (countriesCount > 0) {
      bits.add(_fact(
        c,
        Icons.public_outlined,
        'user_card_stat_countries'.trParams({'n': '$countriesCount'}),
      ));
    }
    final langs = formatLanguagesBadge(languages);
    if (langs.isNotEmpty) {
      bits.add(_fact(c, Icons.translate_rounded, langs));
    }
    return Wrap(
      spacing: 10.dp,
      runSpacing: 6.dp,
      children: bits,
    );
  }

  Widget _fact(AppColors c, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13.dp, color: c.textFaint),
        SizedBox(width: 4.dp),
        Text(
          text,
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
  }

  Widget _quickActionsRow(AppColors c) {
    final actions = <(IconData, String, VoidCallback?)>[
      (Icons.chat_bubble_outline_rounded, 'user_card_action_chat', onMessage),
      if (onCall != null) (Icons.call_outlined, 'user_card_action_call', onCall),
      (
        Icons.mic_none_rounded,
        'user_card_action_live',
        onLiveTranslate,
      ),
      (
        Icons.storefront_outlined,
        'user_card_action_products',
        onProducts,
      ),
      (Icons.person_outline_rounded, 'user_card_action_profile', onProfile),
    ];
    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) SizedBox(width: 4.dp),
          Expanded(
            child: _QuickActionBtn(
              icon: actions[i].$1,
              label: actions[i].$2.tr,
              onTap: actions[i].$3,
              primary: i == 0,
            ),
          ),
        ],
      ],
    );
  }

  String? _countryLabel(String? code) {
    final raw = (code ?? '').trim().toUpperCase();
    if (raw.isEmpty) return null;
    try {
      if (Get.isRegistered<CountriesService>()) {
        final match = Get.find<CountriesService>().findByCode(raw);
        if (match != null) {
          final flag = match.flagEmoji.trim();
          final name = match.localizedName.trim();
          if (flag.isNotEmpty && name.isNotEmpty) return '$flag $name';
          if (name.isNotEmpty) return name;
        }
      }
      for (final o in kFallbackCountries) {
        if (o.code.toUpperCase() == raw) {
          final flag = o.flagEmoji.trim();
          final name = o.localizedName.trim();
          if (flag.isNotEmpty && name.isNotEmpty) return '$flag $name';
          if (name.isNotEmpty) return name;
        }
      }
    } catch (_) {}
    return raw;
  }
}

class _QuickActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;

  const _QuickActionBtn({
    required this.icon,
    required this.label,
    this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final radius = BorderRadius.circular(11.dp);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          padding: EdgeInsets.symmetric(horizontal: 2.dp, vertical: 8.dp),
          decoration: BoxDecoration(
            color: primary ? null : c.surface,
            gradient: primary ? limeButtonGradient : null,
            borderRadius: radius,
            border: primary
                ? null
                : Border.all(color: c.outline.withValues(alpha: 0.65)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18.dp,
                color: primary ? c.onAccent : c.textPrimary,
              ),
              SizedBox(height: 3.dp),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: primary ? c.onAccent : c.textPrimary,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool muted;

  const _ActionChip({
    required this.emoji,
    required this.label,
    this.onTap,
    this.primary = false,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final radius = BorderRadius.circular(12.dp);
    final enabled = onTap != null && !muted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: radius,
        child: Ink(
          padding: EdgeInsets.symmetric(horizontal: 10.dp, vertical: 10.dp),
          decoration: BoxDecoration(
            color: primary && enabled ? null : c.surface,
            gradient: primary && enabled ? limeButtonGradient : null,
            borderRadius: radius,
            border: primary && enabled
                ? null
                : Border.all(color: c.outline.withValues(alpha: 0.7)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: TextStyle(fontSize: 13.sp)),
              SizedBox(width: 6.dp),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primary && enabled
                        ? c.onAccent
                        : (muted ? c.textFaint : c.textPrimary),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
