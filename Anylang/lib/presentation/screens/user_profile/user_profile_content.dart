import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import '../../../data/local/session_store.dart';
import '../../modal/full_screen_image_dialog.dart';
import '../../modal/scam_risk_bottom_sheet.dart';
import '../../ui/factory_verification.dart';
import '../../ui/app_empty_state.dart';
import '../../ui/app_top_bar.dart';
import '../../ui/buttons/my_icon_button.dart';
import '../../ui/buttons/rich_button.dart';
import '../../ui/gradient_background.dart';
import '../../ui/items/info_row.dart';
import '../../ui/items/pill_badge.dart';
import '../../ui/items/product_grid_card.dart';
import '../../ui/language_flag.dart';
import '../../ui/profile_avatar.dart';
import '../../ui/profile_badges_carousel.dart';
import '../../ui/theme/colors.dart';
import '../../ui/theme/gradients.dart';
import '../../ui/verification_cta_button.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/payment_method_labels.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import 'user_profile_action.dart';
import 'user_profile_payload.dart';
import 'user_profile_state.dart';

class UserProfileContent extends ScreenContent<UserProfileState> {

  @override
  Widget build(BuildContext context, UserProfileState state, FutureOr<void> Function(MyAction action) sendAction) {
    final c = context.appColors;

    return GradientBackground(
      child: SafeArea(
        child: Obx(() {
          final d = state.dataRx.value;
          final loading = state.profileLoading.value;
          if (d == null) return const SizedBox.shrink();
          return Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16.dp, 4.dp, 16.dp, 0),
                child: AppTopBar(
                  title: 'profile_title'.tr,
                  onBack: () => sendAction(Back()),
                  trailing: state.profileRefreshing.value
                      ? _refreshingBadge(c)
                      : null,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16.dp, 8.dp, 16.dp, 24.dp),
                  child: Column(
                    children: [
                      _avatar(c, d),
                      SizedBox(height: 14.dp),
                      _nameRow(c, d),
                      if (loading) ...[
                        SizedBox(height: 18.dp),
                        _profileShimmer(c),
                      ] else ...[
                        SizedBox(height: 6.dp),
                        _subtitle(c, d),
                        if ((d.bio ?? '').trim().isNotEmpty) ...[
                          SizedBox(height: 10.dp),
                          _bioText(c, d.bio!.trim()),
                        ],
                        if (d.business && _isOwnProfile(d)) ...[
                          SizedBox(height: 10.dp),
                          _ownVerificationCta(d, sendAction),
                        ],
                        Builder(
                          builder: (_) {
                            final showTrusted = d.business &&
                                (d.documentsVerified || d.verified);
                            final showVerifiedPill = d.business &&
                                !d.factoryVerification.factoryVerified &&
                                d.verified &&
                                !d.documentsVerified;
                            final carousel = ProfileBadgesCarousel(
                              connections: d.networkingConnections,
                              countries: d.networkingCountries,
                              trust: d.networkingTrust ?? d.trustScore?.score,
                              showTrustedMark: showTrusted,
                              showVerifiedPill: showVerifiedPill,
                              factoryVerification: d.business
                                  ? d.factoryVerification
                                  : const FactoryVerification(),
                              onTrustTap: d.business && d.trustScore != null
                                  ? () =>
                                      sendAction(OpenUserTrustScoreDetails())
                                  : null,
                            );
                            if (!carousel.hasAny) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: EdgeInsets.only(top: 12.dp),
                              child: carousel,
                            );
                          },
                        ),
                        if (d.business &&
                            d.scamRisk?.hasWarning == true &&
                            !d.documentsVerified) ...[
                          SizedBox(height: 12.dp),
                          ScamRiskBanner(
                            risk: d.scamRisk!,
                            onTap: () => showScamRiskBottomSheet(
                              context,
                              risk: d.scamRisk!,
                            ),
                          ),
                        ],
                        SizedBox(height: 18.dp),
                        _actions(c, state, d, sendAction),
                        SizedBox(height: 18.dp),
                        _infoCard(c, d, sendAction),
                        if (d.business && _hasAbout(d)) ...[
                          SizedBox(height: 18.dp),
                          _sectionTitle(c, 'business_about_section'.tr),
                          SizedBox(height: 10.dp),
                          _aboutCard(c, d),
                        ],
                        if (d.business && _hasTrade(d)) ...[
                          SizedBox(height: 18.dp),
                          _sectionTitle(c, 'business_trade_section'.tr),
                          SizedBox(height: 10.dp),
                          _tradeCard(c, d),
                        ],
                        if (d.business) ...[
                          SizedBox(height: 20.dp),
                          _completeness(c, d),
                        ],
                        if (d.business && d.certificates.isNotEmpty) ...[
                          SizedBox(height: 20.dp),
                          _sectionTitle(c, 'profile_certificates'.tr),
                          SizedBox(height: 10.dp),
                          _certificates(c, d),
                        ],
                        if (d.business && d.factoryImageUrls.isNotEmpty) ...[
                          SizedBox(height: 20.dp),
                          _sectionTitle(c, 'profile_factory_images'.tr),
                          SizedBox(height: 10.dp),
                          _factoryImages(context, d),
                        ],
                        if (d.business) ...[
                          SizedBox(height: 20.dp),
                          _sectionTitle(
                            c,
                            '${'profile_listings'.tr} · ${d.listings}',
                          ),
                          SizedBox(height: 12.dp),
                          _listings(state, sendAction),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _profileShimmer(AppColors c) {
    final base = c.textFaint.withValues(alpha: 0.22);
    Widget bar({double width = double.infinity, double height = 12}) {
      return _ShimmerBlock(
        color: base,
        width: width,
        height: height.dp,
        radius: 8.dp,
      );
    }

    return Column(
      children: [
        bar(width: 180.dp, height: 14),
        SizedBox(height: 16.dp),
        Row(
          children: [
            Expanded(
              child: _ShimmerBlock(
                color: base,
                height: 48.dp,
                radius: 14.dp,
              ),
            ),
            SizedBox(width: 10.dp),
            _ShimmerBlock(
              color: base,
              width: 48.dp,
              height: 48.dp,
              radius: 14.dp,
            ),
          ],
        ),
        SizedBox(height: 18.dp),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16.dp),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16.dp),
            border: Border.all(color: c.surfaceBorder, width: 0.7),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bar(width: 120.dp),
              SizedBox(height: 12.dp),
              bar(),
              SizedBox(height: 8.dp),
              bar(width: 220.dp),
              SizedBox(height: 8.dp),
              bar(width: 160.dp),
            ],
          ),
        ),
        SizedBox(height: 18.dp),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16.dp),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16.dp),
            border: Border.all(color: c.surfaceBorder, width: 0.7),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bar(width: 100.dp),
              SizedBox(height: 12.dp),
              bar(),
              SizedBox(height: 8.dp),
              bar(),
              SizedBox(height: 8.dp),
              bar(width: 180.dp),
            ],
          ),
        ),
      ],
    );
  }

  Widget _refreshingBadge(AppColors c) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.dp, vertical: 6.dp),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.surfaceBorder, width: 0.7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14.dp,
            height: 14.dp,
            child: CircularProgressIndicator(
              strokeWidth: 1.8,
              color: c.accent,
            ),
          ),
          SizedBox(width: 7.dp),
          Text(
            'profile_updating'.tr,
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

  Widget _avatar(AppColors c, UserProfilePayload d) {
    return ProfileAvatar(
      initial: d.initial,
      gradient: d.avatarGradient,
      shape: ProfileAvatarShape.circle,
      imageUrl: d.avatarUrl,
    );
  }

  Widget _nameRow(AppColors c, UserProfilePayload d) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            d.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: c.textPrimary, fontSize: 22.sp, fontWeight: FontWeight.w700),
          ),
        ),
        if (d.business) ...[
          SizedBox(width: 8.dp),
          _businessBadge(c),
        ],
        if (d.verified || d.documentsVerified || d.factoryVerification.factoryVerified) ...[
          SizedBox(width: 6.dp),
          if (d.factoryVerification.factoryVerified || d.documentsVerified)
            Icon(Icons.verified_rounded, size: 20.dp, color: c.accent)
          else
            SvgPicture.asset('assets/icons/ic_verified.svg', width: 20.dp, height: 20.dp),
        ],
      ],
    );
  }

  bool _isOwnProfile(UserProfilePayload d) {
    final me = SessionStore.userId();
    return me != null && d.id > 0 && d.id == me;
  }

  Widget _ownVerificationCta(
    UserProfilePayload d,
    void Function(MyAction) sendAction,
  ) {
    final approved = d.documentsVerified || d.verificationStatus == 'approved';
    final pending = d.verificationStatus == 'pending';
    final label = approved
        ? 'verification_cta_approved'.tr
        : pending
            ? 'verification_cta_pending'.tr
            : 'verification_cta'.tr;
    return VerificationCtaButton(
      label: label,
      verified: approved,
      pending: pending,
      onTap: () => sendAction(OpenOwnBusinessVerification()),
    );
  }

  Widget _subtitle(AppColors c, UserProfilePayload d) {
    final roleText = d.role.isEmpty
        ? ''
        : (d.role.startsWith('business_role_') ? d.role.tr : d.role);
    final text = d.business
        ? (roleText.isEmpty ? d.country : '${d.country} · $roleText')
        : (d.phone.isEmpty ? d.country : '${d.country} · ${d.phone}');
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
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: c.textSecondary, fontSize: 13.sp),
          ),
        ),
      ],
    );
  }

  Widget _bioText(AppColors c, String bio) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.dp),
      child: Text(
        bio,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: c.textPrimary,
          fontSize: 14.sp,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _businessBadge(AppColors c) {
    return PillBadge(
      label: 'profile_business'.tr,
      background: c.accentSoft,
      foreground: c.accentText,
      borderColor: c.accent,
      fontSize: 12,
    );
  }

  Widget _actions(
    AppColors c,
    UserProfileState state,
    UserProfilePayload d,
    void Function(MyAction) sendAction,
  ) {
    final radius = BorderRadius.circular(14.dp);
    final me = SessionStore.userId();
    final showFriend = d.id > 0 && (me == null || d.id != me);
    return Row(
      children: [
        Expanded(
          child: RichButton(
            text: 'profile_write'.tr,
            onTap: () => sendAction(WriteMessage()),
            iconNearText: true,
            startIcon: SvgPicture.asset('assets/icons/ic_contact.svg', width: 18.dp, height: 18.dp),
            textColor: c.onAccent,
            textStyle: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
            padding: EdgeInsets.symmetric(vertical: 14.dp, horizontal: 16.dp),
            borderRadius: radius,
            decoration: BoxDecoration(gradient: limeButtonGradient, borderRadius: radius),
          ),
        ),
        if (showFriend) ...[
          SizedBox(width: 10.dp),
          Obx(() => _friendButton(c, state, sendAction)),
        ],
        if (d.business) ...[
          SizedBox(width: 10.dp),
          MyIconButton(
            onClick: () => sendAction(OpenCompanyTradeAssistant()),
            icon: Icons.auto_awesome_rounded,
            iconColor: c.accentText,
            iconSize: 20.dp,
            backgroundColor: c.accentSoft,
            borderRadius: 14.dp,
            padding: EdgeInsets.all(14.dp),
            border: Border.all(color: c.accent.withValues(alpha: 0.45), width: 0.7),
          ),
        ],
        if (d.business && showFriend) ...[
          SizedBox(width: 10.dp),
          MyIconButton(
            onClick: () => sendAction(WriteCompanyReview()),
            icon: Icons.rate_review_rounded,
            iconColor: c.accentText,
            iconSize: 20.dp,
            backgroundColor: c.accentSoft,
            borderRadius: 14.dp,
            padding: EdgeInsets.all(14.dp),
            border: Border.all(color: c.accent.withValues(alpha: 0.45), width: 0.7),
          ),
        ],
        if (d.business && (d.website ?? '').trim().isNotEmpty) ...[
          SizedBox(width: 10.dp),
          MyIconButton(
            onClick: () => sendAction(OpenWebsite()),
            svgIcon: 'assets/icons/ic_globe.svg',
            iconColor: c.textPrimary,
            iconSize: 20.dp,
            backgroundColor: c.surface,
            borderRadius: 14.dp,
            padding: EdgeInsets.all(14.dp),
            border: Border.all(color: c.outline, width: 0.7),
          ),
        ],
      ],
    );
  }

  Widget _friendButton(
    AppColors c,
    UserProfileState state,
    void Function(MyAction) sendAction,
  ) {
    final status = state.friendshipStatus.value;
    final incoming = state.isRequestIncoming.value;
    final busy = state.friendBusy.value;

    if (status == 'accepted') {
      return MyIconButton(
        onClick: () => showAppMessage('add_friend_is_friend'.tr),
        icon: Icons.check_circle_rounded,
        iconColor: c.accentText,
        iconSize: 22.dp,
        backgroundColor: c.accentSoft,
        borderRadius: 14.dp,
        padding: EdgeInsets.all(14.dp),
        border: Border.all(color: c.accent.withValues(alpha: 0.45), width: 0.7),
      );
    }

    if (status == 'pending' && incoming) {
      return MyIconButton(
        onClick: busy ? () {} : () => sendAction(AcceptFriendFromProfile()),
        icon: Icons.person_add_alt_1_rounded,
        iconColor: c.onAccent,
        iconSize: 22.dp,
        backgroundColor: c.accent,
        borderRadius: 14.dp,
        padding: EdgeInsets.all(14.dp),
      );
    }

    if (status == 'pending') {
      return MyIconButton(
        onClick: busy ? () {} : () => sendAction(CancelFriendFromProfile()),
        svgIcon: 'assets/icons/ic_friends.svg',
        iconColor: c.textFaint,
        iconSize: 20.dp,
        backgroundColor: c.surface,
        borderRadius: 14.dp,
        padding: EdgeInsets.all(14.dp),
        border: Border.all(color: c.outline, width: 0.7),
      );
    }

    return MyIconButton(
      onClick: busy ? () {} : () => sendAction(AddFriendFromProfile()),
      svgIcon: 'assets/icons/ic_friends.svg',
      iconColor: c.textPrimary,
      iconSize: 20.dp,
      backgroundColor: c.surface,
      borderRadius: 14.dp,
      padding: EdgeInsets.all(14.dp),
      border: Border.all(color: c.outline, width: 0.7),
    );
  }

  Widget _infoCard(AppColors c, UserProfilePayload d, void Function(MyAction) sendAction) {
    final roleText = d.role.isEmpty
        ? ''
        : (d.role.startsWith('business_role_') ? d.role.tr : d.role);
    final rows = <Widget>[
      InfoRow(iconAsset: 'assets/icons/ic_location.svg', label: 'profile_country'.tr, value: d.country),
      if (d.business) ...[
        if (roleText.isNotEmpty)
          InfoRow(iconAsset: 'assets/icons/ic_activity.svg', label: 'profile_activity'.tr, value: roleText),
        if ((d.experience ?? '').trim().isNotEmpty)
          InfoRow(iconAsset: 'assets/icons/ic_clock.svg', label: 'profile_experience'.tr, value: d.experience!),
        if ((d.website ?? '').trim().isNotEmpty)
          InfoRow(
            iconAsset: 'assets/icons/ic_globe.svg',
            label: 'profile_website'.tr,
            value: d.website!,
            valueColor: c.accentText,
            onTap: () => sendAction(OpenWebsite()),
          ),
      ],
      if (d.phone.trim().isNotEmpty)
        InfoRow(iconAsset: 'assets/icons/ic_phone.svg', label: 'profile_phone'.tr, value: d.phone),
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

  bool _hasTrade(UserProfilePayload d) {
    return (d.moq ?? '').isNotEmpty ||
        (d.productionCapacity ?? '').isNotEmpty ||
        d.paymentMethods.isNotEmpty;
  }

  bool _hasAbout(UserProfilePayload d) {
    return _localizedDescription(d).isNotEmpty ||
        (d.seoText ?? '').isNotEmpty ||
        d.keywords.isNotEmpty;
  }

  String _localizedDescription(UserProfilePayload d) {
    final code = (Get.locale?.languageCode ?? 'uz').toLowerCase();
    final fromI18n = d.descriptionI18n[code]?.trim() ?? '';
    if (fromI18n.isNotEmpty) return fromI18n;
    return (d.description ?? '').trim();
  }

  Widget _aboutCard(AppColors c, UserProfilePayload d) {
    final about = _localizedDescription(d);
    final seo = (d.seoText ?? '').trim();
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.dp),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18.dp),
        border: Border.all(color: c.surfaceBorder, width: 0.7),
        boxShadow: c.glassShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (about.isNotEmpty)
            Text(
              about,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 14.sp,
                height: 1.4,
              ),
            ),
          if (seo.isNotEmpty) ...[
            if (about.isNotEmpty) SizedBox(height: 12.dp),
            Text(
              'business_seo'.tr,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 4.dp),
            Text(
              seo,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 13.sp,
                height: 1.35,
              ),
            ),
          ],
          if (d.keywords.isNotEmpty) ...[
            SizedBox(height: 12.dp),
            Text(
              'business_keywords'.tr,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8.dp),
            Wrap(
              spacing: 6.dp,
              runSpacing: 6.dp,
              children: [
                for (final kw in d.keywords)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.dp,
                      vertical: 6.dp,
                    ),
                    decoration: BoxDecoration(
                      color: c.accentSoft,
                      borderRadius: BorderRadius.circular(999.dp),
                    ),
                    child: Text(
                      kw,
                      style: TextStyle(
                        color: c.accentText,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (d.descriptionI18n.length > 1) ...[
            SizedBox(height: 10.dp),
            Text(
              'business_ai_translations'.trParams({
                'n': '${d.descriptionI18n.length}',
              }),
              style: TextStyle(
                color: c.textFaint,
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tradeCard(AppColors c, UserProfilePayload d) {
    final rows = <Widget>[
      if ((d.moq ?? '').isNotEmpty)
        InfoRow(icon: Icons.shopping_basket_outlined, label: 'business_moq'.tr, value: d.moq!),
      if ((d.productionCapacity ?? '').isNotEmpty)
        InfoRow(
          icon: Icons.precision_manufacturing_outlined,
          label: 'business_capacity'.tr,
          value: d.productionCapacity!,
        ),
      if (d.paymentMethods.isNotEmpty)
        InfoRow(
          icon: Icons.payments_outlined,
          label: 'business_payment_methods'.tr,
          value: formatPaymentMethods(d.paymentMethods),
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

  Widget _completeness(AppColors c, UserProfilePayload d) {
    final pct = (d.completeness ?? 0).clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('profile_completeness'.tr, style: TextStyle(color: c.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('$pct%', style: TextStyle(color: c.accentText, fontSize: 13.sp, fontWeight: FontWeight.w700)),
          ],
        ),
        SizedBox(height: 8.dp),
        ClipRRect(
          borderRadius: BorderRadius.circular(99.dp),
          child: Stack(
            children: [
              Container(height: 8.dp, color: c.surface),
              FractionallySizedBox(
                widthFactor: pct / 100,
                child: Container(
                  height: 8.dp,
                  decoration: const BoxDecoration(gradient: limeButtonGradient),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(AppColors c, String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(text, style: TextStyle(color: c.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w700)),
    );
  }

  Widget _certificates(AppColors c, UserProfilePayload d) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 10.dp,
        runSpacing: 10.dp,
        children: [
          for (final cert in d.certificates)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.dp, vertical: 9.dp),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(12.dp),
                border: Border.all(color: c.outline),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    'assets/icons/ic_cert.svg',
                    width: 18.dp,
                    height: 18.dp,
                    colorFilter: ColorFilter.mode(c.accent, BlendMode.srcIn),
                  ),
                  SizedBox(width: 8.dp),
                  Text(cert, style: TextStyle(color: c.textPrimary, fontSize: 13.sp, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _factoryImages(BuildContext context, UserProfilePayload d) {
    final urls = d.factoryImageUrls;
    return SizedBox(
      height: 90.dp,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, _) => SizedBox(width: 10.dp),
        itemBuilder: (_, i) {
          final url = urls[i];
          return Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14.dp),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => showFullScreenImage(context, url: url),
              child: SizedBox(
                width: 120.dp,
                height: 90.dp,
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: prodBlueGradient,
                      borderRadius: BorderRadius.circular(14.dp),
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/icons/ic_prod_image.svg',
                        width: 26.dp,
                        height: 26.dp,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _listings(UserProfileState state, void Function(MyAction) sendAction) {
    return Obx(() {
      final items = state.listings.toList();
      if (state.listingsLoading.value && items.isEmpty) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 12.dp),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      }
      final listErr = state.listingsError.value;
      if (listErr != null && listErr.isNotEmpty) {
        return AppEmptyState(
          icon: Icons.error_outline_rounded,
          title: 'profile_listings_load_failed'.tr,
          subtitle: listErr,
        );
      }
      if (items.isEmpty) {
        return AppEmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'profile_listings_empty'.tr,
        );
      }
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12.dp,
          mainAxisSpacing: 12.dp,
          childAspectRatio: 0.9,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final p = items[i];
          return ProductGridCard(
            iconAsset: p.iconAsset,
            tileGradient: p.tileGradient,
            name: p.name,
            subtitle: p.subtitle,
            price: p.price,
            views: p.views,
            imageUrl: p.imageUrl,
            onTap: () => sendAction(OpenListing(p)),
          );
        },
      );
    });
  }
}

class _ShimmerBlock extends StatefulWidget {
  final Color color;
  final double? width;
  final double height;
  final double radius;

  const _ShimmerBlock({
    required this.color,
    required this.height,
    required this.radius,
    this.width,
  });

  @override
  State<_ShimmerBlock> createState() => _ShimmerBlockState();
}

class _ShimmerBlockState extends State<_ShimmerBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final a = 0.45 + _c.value * 0.55;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: a),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}
