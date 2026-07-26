import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/core/mappers.dart';
import '../../modal/business_benefits_bottom_sheet.dart';
import '../../modal/trust_score_bottom_sheet.dart';
import '../../modal/scam_risk_bottom_sheet.dart';
import '../../ui/ai_matching_card.dart';
import '../../ui/market_analytics_card.dart';
import '../../ui/factory_verification_badges.dart';
import '../../ui/app_empty_state.dart';
import '../../ui/app_loading.dart';
import '../../ui/buttons/secondary_button.dart';
import '../../ui/items/info_row.dart';
import '../../ui/items/pill_badge.dart';
import '../../ui/items/profile_stat_card.dart';
import '../../ui/language_flag.dart';
import '../../ui/networking_score_bar.dart';
import '../../ui/profile_avatar.dart';
import '../../ui/theme/colors.dart';
import '../../ui/theme/gradients.dart';
import '../../utils/formatters/time_formatter.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import 'profile_account.dart';
import 'profile_achievements_section.dart';
import 'profile_action.dart';
import 'profile_analytics_section.dart';
import 'profile_anylang_id_card.dart';
import 'profile_pressable.dart';
import 'profile_state.dart';

/// S14 — o'z profili. `isBusiness`ga qarab shaxsiy (obuna) yoki biznes
/// (e'lonlar/statistika) ko'rinishi ko'rsatiladi.
class ProfileContent extends ScreenContent<ProfileState> {
  ProfileContent() : super(color: Colors.transparent);

  @override
  Widget build(BuildContext context, ProfileState state,
      FutureOr<void> Function(MyAction action) sendAction) {
    final c = context.appColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: c.isDark ? profilePageGradientDark : profilePageGradientLight,
      ),
      child: Padding(
        padding: EdgeInsets.only(top: 8.dp),
        child: Obx(() {
          if (state.loading.value && state.account.value == null) {
            return const AppLoading();
          }
          final err = state.error.value;
          final d = state.account.value;
          if (d == null) {
            return Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 28.dp),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppEmptyState(
                      icon: Icons.person_off_outlined,
                      title: 'profile_load_failed'.tr,
                      subtitle: err,
                    ),
                    SizedBox(height: 16.dp),
                    SecondaryButton(
                      text: 'common_retry'.tr,
                      onTap: () => sendAction(RetryProfileLoad()),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            color: c.accentText,
            onRefresh: () async { await sendAction(RefreshProfile()); },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20.dp, 8.dp, 20.dp, 24.dp),
              child: Column(
                children: [
                  _avatarHeader(c, d, sendAction),
                  SizedBox(height: 14.dp),
                  _nameRow(c, d),
                  SizedBox(height: 8.dp),
                  _idHandleRow(c, d, sendAction),
                  SizedBox(height: 6.dp),
                  _subtitleRow(c, d),
                  if (d.networkingConnections > 0 ||
                      d.networkingCountries > 0 ||
                      d.networkingTrust != null) ...[
                    SizedBox(height: 12.dp),
                    NetworkingScoreBar(
                      connections: d.networkingConnections,
                      countries: d.networkingCountries,
                      trust: d.networkingTrust ?? d.trustScore?.score,
                    ),
                  ],
                  if (d.isBusiness) ...[
                    SizedBox(height: 12.dp),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8.dp,
                      runSpacing: 8.dp,
                      children: [
                        ProfilePressable(
                          borderRadius: BorderRadius.circular(999.dp),
                          onTap: () => showBusinessBenefitsBottomSheet(
                            context,
                            sendAction: sendAction,
                          ),
                          child: PillBadge(
                            label: 'profile_business'.tr,
                            background: c.accentSoft,
                            foreground: c.accentText,
                            borderColor: c.accent,
                            fontSize: 12,
                          ),
                        ),
                        if (!d.factoryVerification.factoryVerified && d.verified)
                          PillBadge(
                            label: 'profile_verified'.tr,
                            icon: Icons.verified_rounded,
                            background: c.accent,
                            foreground: c.onAccent,
                            fontSize: 12,
                          ),
                        if (d.trustScore != null)
                          TrustScoreBadge(
                            trust: d.trustScore!,
                            onTap: () => showTrustScoreBottomSheet(
                              context,
                              trust: d.trustScore!,
                            ),
                          ),
                      ],
                    ),
                    if (d.factoryVerification.hasAny) ...[
                      SizedBox(height: 10.dp),
                      FactoryVerificationBadges(data: d.factoryVerification),
                    ],
                    if (d.scamRisk?.hasWarning == true) ...[
                      SizedBox(height: 12.dp),
                      ScamRiskBanner(
                        risk: d.scamRisk!,
                        onTap: () => showScamRiskBottomSheet(
                          context,
                          risk: d.scamRisk!,
                        ),
                      ),
                    ],
                  ],
                  SizedBox(height: 18.dp),
                  _statsGrid(c, d),
                  SizedBox(height: 18.dp),
                  _quickActions(c, d, sendAction),
                  SizedBox(height: 18.dp),
                  ProfileAnyLangIdCard(
                    userId: d.id,
                    anylangId: d.username ?? d.anylangNumber,
                    handle: d.handle,
                    sendAction: sendAction,
                  ),
                  SizedBox(height: 18.dp),
                  ProfileAnalyticsSection(insights: d.insights),
                  if (d.isBusiness) ...[
                    SizedBox(height: 18.dp),
                    Obx(
                      () => AiMatchingCard(
                        result: state.aiMatching.value,
                        loading: state.aiMatchingLoading.value,
                        loadFailed: state.aiMatchingLoadFailed.value,
                        onTap: () => sendAction(OpenAiMatching()),
                        onRetry: () => sendAction(RetryAiMatching()),
                      ),
                    ),
                    SizedBox(height: 12.dp),
                    Obx(
                      () => MarketAnalyticsCard(
                        result: state.marketAnalytics.value,
                        loading: state.marketAnalyticsLoading.value,
                        loadFailed: state.marketAnalyticsLoadFailed.value,
                        onTap: () => sendAction(OpenMarketAnalytics()),
                        onRetry: () => sendAction(RetryMarketAnalytics()),
                      ),
                    ),
                    if (_hasTradeInfo(d)) ...[
                      SizedBox(height: 18.dp),
                      _tradeInfoCard(c, d),
                    ],
                    if (d.certificates.isNotEmpty) ...[
                      SizedBox(height: 18.dp),
                      _certificatesSection(c, d),
                    ],
                    if (d.factoryMedia.isNotEmpty) ...[
                      SizedBox(height: 18.dp),
                      _factorySection(c, d, sendAction),
                    ],
                  ] else ...[
                    SizedBox(height: 18.dp),
                    _infoCard(c, d),
                  ],
                  SizedBox(height: 18.dp),
                  _settingsHub(c, sendAction),
                  SizedBox(height: 18.dp),
                  ProfileAchievementsSection(
                    achievements: d.insights.achievements,
                  ),
                  if (d.isBusiness) ...[
                    SizedBox(height: 22.dp),
                    _listingsSection(c, d, sendAction),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _avatarHeader(
    AppColors c,
    ProfileAccount d,
    void Function(MyAction) sendAction,
  ) {
    return SizedBox(
      width: 88.dp,
      height: 88.dp,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: (d.avatarUrl?.trim().isNotEmpty == true)
                  ? () => sendAction(OpenProfileAvatar())
                  : () => sendAction(ChangeAvatarQuick()),
              child: ProfileAvatar(
                initial: d.initial,
                gradient: d.avatarGradient,
                imageUrl: d.avatarUrl,
                shape: ProfileAvatarShape.circle,
              ),
            ),
          ),
          Positioned(
            right: -2.dp,
            bottom: -2.dp,
            child: ProfilePressable(
              borderRadius: BorderRadius.circular(999.dp),
              onTap: () => sendAction(ChangeAvatarQuick()),
              child: Container(
                width: 34.dp,
                height: 34.dp,
                decoration: BoxDecoration(
                  color: c.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.background, width: 2.5),
                  boxShadow: c.glassShadow,
                ),
                child: Icon(
                  Icons.photo_camera_rounded,
                  size: 16.dp,
                  color: c.onAccent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nameRow(AppColors c, ProfileAccount d) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            d.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 22.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (d.verified) ...[
          SizedBox(width: 6.dp),
          Icon(Icons.verified_rounded, size: 20.dp, color: c.accentText),
          SizedBox(width: 4.dp),
          Text(
            'profile_verified'.tr,
            style: TextStyle(
              color: c.accentText,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (d.showPremiumBadge) ...[
          SizedBox(width: 8.dp),
          PillBadge(
            label: 'profile_premium'.tr,
            icon: Icons.workspace_premium_rounded,
            background: c.accent,
            foreground: c.onAccent,
          ),
        ],
      ],
    );
  }

  Widget _idHandleRow(
    AppColors c,
    ProfileAccount d,
    void Function(MyAction) sendAction,
  ) {
    final idText = d.username ?? d.anylangNumber;
    final parts = <String>[
      if (d.handle.isNotEmpty) d.handle,
      if (idText.isNotEmpty) 'ID $idText',
    ];
    if (parts.isEmpty) return const SizedBox.shrink();

    return ProfilePressable(
      borderRadius: BorderRadius.circular(12.dp),
      onTap: () => sendAction(CopyAnyLangId()),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.dp, vertical: 6.dp),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                parts.join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(width: 6.dp),
            Icon(Icons.copy_rounded, size: 16.dp, color: c.accentText),
          ],
        ),
      ),
    );
  }

  Widget _subtitleRow(AppColors c, ProfileAccount d) {
    final roleKey = d.roleLabel;
    final roleText = roleKey.isEmpty ? '' : roleKey.tr;
    final subtitle = d.isBusiness
        ? (roleText.isEmpty ? d.country : '${d.country} · $roleText')
        : d.country;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        LanguageFlag(
          url: d.flagAsset,
          width: 18.dp,
          height: 13.dp,
        ),
        SizedBox(width: 6.dp),
        Flexible(
          child: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: c.textSecondary, fontSize: 13.sp),
          ),
        ),
      ],
    );
  }

  Widget _infoCard(AppColors c, ProfileAccount d) {
    final subLabel = d.subscriptionLabel ?? d.subscriptionPlan ?? '';
    final rows = <Widget>[
      InfoRow(
        icon: Icons.dialpad_rounded,
        label: 'numbers_my_label'.tr,
        value: d.username ?? '',
        valueColor: c.accentText,
      ),
      InfoRow(
        icon: Icons.language_outlined,
        label: 'profile_native_language'.tr,
        value: d.nativeLanguage ?? '',
      ),
      InfoRow(
        icon: Icons.location_on_outlined,
        label: 'profile_country'.tr,
        value: d.country,
      ),
      InfoRow(
        icon: Icons.calendar_today_outlined,
        label: 'profile_member_since'.tr,
        value: d.memberSince ?? '',
      ),
      if (subLabel.isNotEmpty)
        InfoRow(
          icon: Icons.workspace_premium_outlined,
          label: 'profile_subscription'.tr,
          value: subLabel,
          valueColor: d.showPremiumBadge ? c.accentText : null,
        ),
      if (d.subscriptionExpiresAt != null && d.subscriptionActive)
        InfoRow(
          icon: Icons.event_available_outlined,
          label: 'profile_subscription_expires'.tr,
          value: formatDateDots(d.subscriptionExpiresAt!),
        ),
    ];

    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      children.add(rows[i]);
      if (i != rows.length - 1) {
        children.add(Divider(height: 1.dp, thickness: 0.5, color: c.outline));
      }
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.isDark ? const Color(0x99152A42) : const Color(0xCCFFFFFF),
        borderRadius: BorderRadius.circular(18.dp),
        border: Border.all(color: c.surfaceBorder, width: 0.7),
        boxShadow: c.glassShadow,
      ),
      child: Column(children: children),
    );
  }

  Widget _statsGrid(AppColors c, ProfileAccount d) {
    final ins = d.insights;
    final rating = (d.rating ?? ins.rating) == null
        ? '—'
        : '${(d.rating ?? ins.rating)!.toStringAsFixed(1)}/5';
    final listings = '${d.listingsCount ?? ins.listingsCount}';
    final views = d.viewsCount ?? formatViews(ins.totalViews);
    final trust = ins.trustPercent ?? d.networkingTrust;
    final grads = [
      profileStatGradientA,
      profileStatGradientB,
      profileStatGradientC,
      profileStatGradientA,
    ];

    final cards = <(IconData, String, String, LinearGradient)>[
      (Icons.inventory_2_outlined, listings, 'profile_listings_stat'.tr, grads[0]),
      (Icons.visibility_outlined, views, 'profile_views'.tr, grads[1]),
      (Icons.star_rounded, rating, 'profile_rating'.tr, grads[2]),
      (
        Icons.groups_rounded,
        '${ins.followers}',
        'profile_followers'.tr,
        grads[3],
      ),
      (
        Icons.favorite_rounded,
        '${ins.likes}',
        'profile_likes'.tr,
        grads[0],
      ),
      (
        Icons.translate_rounded,
        '${ins.translationsCount}',
        'profile_translations'.tr,
        grads[1],
      ),
      (
        Icons.verified_user_outlined,
        trust == null ? '—' : '$trust%',
        'profile_trust_pct'.tr,
        grads[2],
      ),
    ];

    return Column(
      children: [
        for (var i = 0; i < cards.length; i += 2) ...[
          if (i > 0) SizedBox(height: 10.dp),
          Row(
            children: [
              Expanded(
                child: ProfileStatCard(
                  icon: cards[i].$1,
                  value: cards[i].$2,
                  label: cards[i].$3,
                  gradient: cards[i].$4,
                  valueColor: cards[i].$1 == Icons.star_rounded &&
                          (d.rating ?? ins.rating) != null
                      ? c.accentText
                      : null,
                ),
              ),
              SizedBox(width: 10.dp),
              Expanded(
                child: i + 1 < cards.length
                    ? ProfileStatCard(
                        icon: cards[i + 1].$1,
                        value: cards[i + 1].$2,
                        label: cards[i + 1].$3,
                        gradient: cards[i + 1].$4,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
        if (d.isBusiness && d.exportCountryCodes.isNotEmpty) ...[
          SizedBox(height: 12.dp),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8.dp,
              runSpacing: 8.dp,
              children: [
                for (final code in d.exportCountryCodes.take(12))
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.dp,
                      vertical: 6.dp,
                    ),
                    decoration: BoxDecoration(
                      color: c.isDark
                          ? const Color(0x66152A42)
                          : const Color(0xCCFFFFFF),
                      borderRadius: BorderRadius.circular(999.dp),
                      border: Border.all(color: c.surfaceBorder, width: 0.7),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LanguageFlag(
                          url: flagAssetForCountry(code),
                          width: 16.dp,
                          height: 11.dp,
                        ),
                        SizedBox(width: 6.dp),
                        Text(
                          formatCountryName(code),
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _quickActions(
    AppColors c,
    ProfileAccount d,
    void Function(MyAction) sendAction,
  ) {
    final actions = <(IconData, String, VoidCallback)>[
      (
        Icons.edit_outlined,
        'profile_edit'.tr,
        () => sendAction(
          d.isBusiness ? EditBusinessInfo() : EditPersonalProfile(),
        ),
      ),
      (
        Icons.workspace_premium_rounded,
        'profile_plans'.tr,
        () => sendAction(OpenSubscription()),
      ),
      if (d.isBusiness)
        (
          Icons.add_box_outlined,
          'profile_post_listing'.tr,
          () => sendAction(AddProductRequested()),
        ),
      (
        Icons.ios_share_rounded,
        'profile_share'.tr,
        () => sendAction(ShareProfile()),
      ),
      (
        Icons.qr_code_2_rounded,
        'profile_qr'.tr,
        () => sendAction(ShowBusinessCardQr()),
      ),
      if (!d.isBusiness)
        (
          Icons.business_center_outlined,
          'profile_business_account'.tr,
          () => sendAction(OpenBusinessAccount()),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'profile_quick_actions'.tr.toUpperCase(),
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 12.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
        SizedBox(height: 10.dp),
        LayoutBuilder(
          builder: (context, constraints) {
            final w = (constraints.maxWidth - 8.dp) / 2;
            return Wrap(
              spacing: 8.dp,
              runSpacing: 8.dp,
              children: [
                for (final a in actions)
                  ProfilePressable(
                    borderRadius: BorderRadius.circular(14.dp),
                    onTap: a.$3,
                    child: Container(
                      width: w,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.dp,
                        vertical: 12.dp,
                      ),
                      decoration: BoxDecoration(
                        color: c.isDark
                            ? const Color(0x99152A42)
                            : const Color(0xCCFFFFFF),
                        borderRadius: BorderRadius.circular(14.dp),
                        border: Border.all(color: c.surfaceBorder, width: 0.7),
                      ),
                      child: Row(
                        children: [
                          Icon(a.$1, size: 18.dp, color: c.accentText),
                          SizedBox(width: 8.dp),
                          Expanded(
                            child: Text(
                              a.$2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 12.5.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  bool _hasTradeInfo(ProfileAccount d) {
    return (d.moq ?? '').isNotEmpty ||
        (d.productionCapacity ?? '').isNotEmpty ||
        (d.leadTime ?? '').isNotEmpty ||
        d.incoterms.isNotEmpty ||
        d.paymentMethods.isNotEmpty;
  }

  Widget _tradeInfoCard(AppColors c, ProfileAccount d) {
    final rows = <Widget>[
      if ((d.moq ?? '').isNotEmpty)
        InfoRow(
          icon: Icons.shopping_basket_outlined,
          label: 'business_moq'.tr,
          value: d.moq!,
        ),
      if ((d.productionCapacity ?? '').isNotEmpty)
        InfoRow(
          icon: Icons.precision_manufacturing_outlined,
          label: 'business_capacity'.tr,
          value: d.productionCapacity!,
        ),
      if ((d.leadTime ?? '').isNotEmpty)
        InfoRow(
          icon: Icons.schedule_outlined,
          label: 'business_lead_time'.tr,
          value: d.leadTime!,
        ),
      if (d.incoterms.isNotEmpty)
        InfoRow(
          icon: Icons.local_shipping_outlined,
          label: 'business_incoterms'.tr,
          value: d.incoterms.join(' · '),
        ),
      if (d.paymentMethods.isNotEmpty)
        InfoRow(
          icon: Icons.payments_outlined,
          label: 'business_payment_methods'.tr,
          value: d.paymentMethods.join(' · '),
        ),
    ];

    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      children.add(rows[i]);
      if (i != rows.length - 1) {
        children.add(Divider(height: 1.dp, thickness: 0.5, color: c.outline));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'business_trade_section'.tr,
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 10.dp),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: c.isDark ? const Color(0x99152A42) : const Color(0xCCFFFFFF),
            borderRadius: BorderRadius.circular(18.dp),
            border: Border.all(color: c.surfaceBorder, width: 0.7),
            boxShadow: c.glassShadow,
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _certificatesSection(AppColors c, ProfileAccount d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'business_certificates'.tr,
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 10.dp),
        Wrap(
          spacing: 8.dp,
          runSpacing: 8.dp,
          children: [
            for (final cert in d.certificates)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.dp, vertical: 8.dp),
                decoration: BoxDecoration(
                  color: c.accentSoft,
                  borderRadius: BorderRadius.circular(12.dp),
                  border: Border.all(
                    color: c.accent.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_outlined, size: 16.dp, color: c.accentText),
                    SizedBox(width: 6.dp),
                    Text(
                      cert,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _factorySection(
    AppColors c,
    ProfileAccount d,
    void Function(MyAction) sendAction,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'profile_factory_videos'.tr,
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 10.dp),
        SizedBox(
          height: 118.dp,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: d.factoryMedia.length,
            separatorBuilder: (_, _) => SizedBox(width: 10.dp),
            itemBuilder: (_, i) {
              final item = d.factoryMedia[i];
              return Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16.dp),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => sendAction(OpenFactoryMedia(item.url)),
                  child: SizedBox(
                    width: 168.dp,
                    height: 118.dp,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          item.url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => DecoratedBox(
                            decoration: BoxDecoration(
                              color: c.surface,
                              borderRadius: BorderRadius.circular(16.dp),
                            ),
                            child: Icon(
                              Icons.factory_outlined,
                              color: c.textFaint,
                              size: 28.dp,
                            ),
                          ),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.45),
                              ],
                            ),
                          ),
                        ),
                        Center(
                          child: Container(
                            width: 42.dp,
                            height: 42.dp,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.7),
                                width: 1.2,
                              ),
                            ),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 26.dp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _settingsHub(AppColors c, void Function(MyAction) sendAction) {
    final tiles = <(IconData, String, String, MyAction)>[
      (
        Icons.language_rounded,
        'profile_settings_language'.tr,
        'settings_app_desc'.tr,
        OpenSettingsLanguage(),
      ),
      (
        Icons.palette_outlined,
        'profile_settings_theme'.tr,
        'settings_theme'.tr,
        OpenSettingsTheme(),
      ),
      (
        Icons.notifications_outlined,
        'profile_settings_notifications'.tr,
        'settings_notifications'.tr,
        OpenSettingsNotifications(),
      ),
      (
        Icons.lock_outline_rounded,
        'profile_settings_privacy'.tr,
        'settings_privacy'.tr,
        OpenSettingsPrivacy(),
      ),
      (
        Icons.shield_outlined,
        'profile_settings_security'.tr,
        'settings_change_password'.tr,
        OpenSettingsSecurity(),
      ),
      (
        Icons.translate_rounded,
        'profile_settings_translation'.tr,
        'settings_smart_translation'.tr,
        OpenSettingsTranslation(),
      ),
      (
        Icons.smart_toy_outlined,
        'profile_settings_ai'.tr,
        'profile_sofiya_desc'.tr,
        OpenSettingsAiAssistant(),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'profile_settings_hub'.tr.toUpperCase(),
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 12.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
        SizedBox(height: 10.dp),
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) SizedBox(height: 10.dp),
          _settingsTile(
            c,
            icon: tiles[i].$1,
            title: tiles[i].$2,
            subtitle: tiles[i].$3,
            onTap: () => sendAction(tiles[i].$4),
          ),
        ],
      ],
    );
  }

  Widget _settingsTile(
    AppColors c, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18.dp),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.dp),
        child: Ink(
          padding: EdgeInsets.all(14.dp),
          decoration: BoxDecoration(
            color: c.isDark ? const Color(0x99152A42) : const Color(0xCCFFFFFF),
            borderRadius: BorderRadius.circular(18.dp),
            border: Border.all(color: c.surfaceBorder, width: 0.7),
            boxShadow: c.glassShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 42.dp,
                height: 42.dp,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.accentSoft,
                  borderRadius: BorderRadius.circular(14.dp),
                ),
                child: Icon(icon, color: c.accentText, size: 22.dp),
              ),
              SizedBox(width: 12.dp),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2.dp),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 12.sp,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: c.textFaint,
                size: 22.dp,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _listingsSection(
    AppColors c,
    ProfileAccount d,
    void Function(MyAction) sendAction,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '${'profile_my_listings'.tr} · ${d.listings.length}',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (d.listings.isNotEmpty)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => sendAction(SeeAllListings()),
                  borderRadius: BorderRadius.circular(8.dp),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 6.dp,
                      vertical: 4.dp,
                    ),
                    child: Text(
                      'products_see_all'.tr,
                      style: TextStyle(
                        color: c.accentText,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              )
            else
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => sendAction(AddProductRequested()),
                  borderRadius: BorderRadius.circular(8.dp),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 6.dp,
                      vertical: 4.dp,
                    ),
                    child: Icon(Icons.add_rounded, size: 20.dp, color: c.accent),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 12.dp),
        if (d.listings.isEmpty)
          AppEmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'profile_listings_empty'.tr,
            subtitle: 'profile_listings_empty_hint'.tr,
            actionLabel: 'add_product_title'.tr,
            onAction: () => sendAction(AddProductRequested()),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12.dp,
              mainAxisSpacing: 12.dp,
              childAspectRatio: 1.05,
            ),
            itemCount: d.listings.length.clamp(0, 6),
            itemBuilder: (_, i) =>
                _ownListingCard(c, d.listings[i], sendAction),
          ),
      ],
    );
  }

  Widget _ownListingCard(
    AppColors c,
    OwnListing listing,
    void Function(MyAction) sendAction,
  ) {
    final radius = BorderRadius.circular(16.dp);
    final img = listing.imageUrl?.trim();
    return Material(
      color: c.surface,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => sendAction(OpenOwnListing(listing)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: img != null && img.isNotEmpty
                  ? Image.network(
                      img,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => DecoratedBox(
                        decoration: BoxDecoration(gradient: listing.tileGradient),
                      ),
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(gradient: listing.tileGradient),
                    ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(12.dp, 10.dp, 12.dp, 12.dp),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    listing.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4.dp),
                  Text(
                    listing.price,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
