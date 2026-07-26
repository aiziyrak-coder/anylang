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

/// Foydalanuvchi kartasi — online/oxirgi faollik, kompaniya, davlat, badge…
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

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final radius = BorderRadius.circular(16.dp);
    final countryLabel = _countryLabel(country);
    final languageLabel = formatLanguagesBadge(languages);
    final activity = formatLastActivity(
      online: online,
      lastSeenAt: lastSeenAt,
    );
    final badge = resolveBusinessBadge(
      businessRole: businessRole,
      keywords: keywords,
      isBusiness: isBusiness || (businessRole ?? '').trim().isNotEmpty,
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.dp, vertical: 6.dp),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Ink(
            padding: EdgeInsets.all(12.dp),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: radius,
              border: Border.all(color: c.surfaceBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProfileAvatar(
                      initial: initial,
                      gradient: avatarGradient,
                      imageUrl: avatarUrl,
                      size: 52,
                      online: online,
                    ),
                    SizedBox(width: 12.dp),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (badge != null) ...[
                            BusinessBadgeChip(info: badge),
                            SizedBox(height: 6.dp),
                          ],
                          Text(
                            activity,
                            style: TextStyle(
                              color: online ? c.accent : c.textFaint,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4.dp),
                          Text(
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
                          if (countryLabel != null) ...[
                            SizedBox(height: 6.dp),
                            _metaRow('🌍', countryLabel, c),
                          ],
                          if (languageLabel.isNotEmpty) ...[
                            SizedBox(height: 4.dp),
                            Text(
                              languageLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: c.textSecondary,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (_hasMiniStats) ...[
                            SizedBox(height: 8.dp),
                            _miniStats(c),
                          ],
                          if (verified) ...[
                            SizedBox(height: 4.dp),
                            _metaRow('✅', 'user_card_verified'.tr, c, accent: true),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (showQuickActions) ...[
                  SizedBox(height: 12.dp),
                  _quickActionsRow(),
                ] else if (showMessage || showAdd) ...[
                  SizedBox(height: 12.dp),
                  Row(
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
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickActionsRow() {
    final actions = <(String, String, VoidCallback?)>[
      ('💬', 'user_card_action_chat', onMessage),
      if (onCall != null) ('📞', 'user_card_action_call', onCall),
      ('🎤', 'user_card_action_live', onLiveTranslate),
      ('📦', 'user_card_action_products', onProducts),
      ('👤', 'user_card_action_profile', onProfile),
    ];
    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) SizedBox(width: 4.dp),
          Expanded(
            child: _QuickActionBtn(
              emoji: actions[i].$1,
              label: actions[i].$2.tr,
              onTap: actions[i].$3,
            ),
          ),
        ],
      ],
    );
  }

  bool get _hasMiniStats =>
      productsCount > 0 || countriesCount > 0 || rating != null;

  Widget _miniStats(AppColors c) {
    final bits = <Widget>[];
    if (productsCount > 0) {
      bits.add(
        _statChip(
          '📦',
          'user_card_stat_products'.trParams({'n': '$productsCount'}),
          c,
        ),
      );
    }
    if (countriesCount > 0) {
      bits.add(
        _statChip(
          '🌍',
          'user_card_stat_countries'.trParams({'n': '$countriesCount'}),
          c,
        ),
      );
    }
    if (rating != null) {
      bits.add(
        _statChip(
          '⭐',
          rating!.toStringAsFixed(1),
          c,
        ),
      );
    }
    return Wrap(
      spacing: 8.dp,
      runSpacing: 6.dp,
      children: bits,
    );
  }

  Widget _statChip(String emoji, String text, AppColors c) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.dp, vertical: 4.dp),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(99.dp),
        border: Border.all(color: c.surfaceBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: TextStyle(fontSize: 11.sp)),
          SizedBox(width: 4.dp),
          Text(
            text,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaRow(String emoji, String text, AppColors c, {bool accent = false}) {
    return Row(
      children: [
        Text(emoji, style: TextStyle(fontSize: 13.sp)),
        SizedBox(width: 6.dp),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent ? c.accent : c.textSecondary,
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
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
  final String emoji;
  final String label;
  final VoidCallback? onTap;

  const _QuickActionBtn({
    required this.emoji,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final radius = BorderRadius.circular(12.dp);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          padding: EdgeInsets.symmetric(horizontal: 2.dp, vertical: 8.dp),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: radius,
            border: Border.all(color: c.outline.withValues(alpha: 0.7)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: TextStyle(fontSize: 16.sp)),
              SizedBox(height: 4.dp),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.textPrimary,
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
            color: primary && enabled
                ? null
                : (muted ? c.surface : c.surface),
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
