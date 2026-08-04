import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/core/mappers.dart';
import '../../ui/app_empty_state.dart';
import '../../ui/app_loading.dart';
import '../../ui/app_top_bar.dart';
import '../../ui/buttons/primary_button.dart';
import '../../ui/gradient_background.dart';
import '../../ui/profile_avatar.dart';
import '../../ui/theme/colors.dart';
import '../../ui/theme/gradients.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import 'marketplace_verified_group_action.dart';
import 'marketplace_verified_group_models.dart';
import 'marketplace_verified_group_state.dart';

class MarketplaceVerifiedGroupContent
    extends ScreenContent<MarketplaceVerifiedGroupState> {
  @override
  Widget build(
    BuildContext context,
    MarketplaceVerifiedGroupState state,
    FutureOr<void> Function(MyAction action) sendAction,
  ) {
    final c = context.appColors;

    return GradientBackground(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.dp, 4.dp, 8.dp, 0),
              child: AppTopBar(
                title: 'marketplace_verified_info_title'.tr,
                onBack: () => sendAction(Back()),
              ),
            ),
            Expanded(
              child: Obx(() {
                if (state.loading.value && state.preview.value == null) {
                  return const Center(child: AppLoading());
                }
                final err = state.loadError.value;
                final data = state.preview.value;
                if (data == null) {
                  return AppEmptyState(
                    icon: Icons.lock_outline_rounded,
                    title: 'marketplace_verified_info_load_failed'.tr,
                    subtitle: err,
                  );
                }
                return RefreshIndicator(
                  color: c.accent,
                  onRefresh: () async {
                    await sendAction(MarketplaceVerifiedGroupRefresh());
                  },
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(16.dp, 8.dp, 16.dp, 24.dp),
                    children: [
                      _HeaderCard(c: c, state: state, data: data),
                      SizedBox(height: 16.dp),
                      _sectionTitle(c, 'marketplace_verified_members'.tr),
                      SizedBox(height: 10.dp),
                      if (data.members.isEmpty)
                        Container(
                          padding: EdgeInsets.all(16.dp),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(16.dp),
                            border: Border.all(color: c.surfaceBorder),
                          ),
                          child: Text(
                            'marketplace_verified_members_empty'.tr,
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 13.sp,
                            ),
                          ),
                        )
                      else
                        _MembersCard(c: c, data: data),
                      SizedBox(height: 18.dp),
                      _TrustCard(
                        c: c,
                        data: data,
                        onTap: () {
                          if (!data.documentsVerified) {
                            sendAction(MarketplaceVerifiedGroupUploadDocs());
                            return;
                          }
                          // Hujjatlar OK — profil trust sheet (o'z hisob).
                          sendAction(MarketplaceVerifiedGroupShowTrust());
                        },
                      ),
                      SizedBox(height: 20.dp),
                      if (data.canJoin || data.joined)
                        PrimaryButton(
                          text: data.joined
                              ? 'marketplace_verified_open_chat'.tr
                              : 'marketplace_verified_join'.tr,
                          isLoading: state.joining.value,
                          onTap: () =>
                              sendAction(MarketplaceVerifiedGroupJoin()),
                        )
                      else
                        PrimaryButton(
                          text: 'marketplace_verified_upload_docs'.tr,
                          onTap: () =>
                              sendAction(MarketplaceVerifiedGroupUploadDocs()),
                        ),
                      if (!data.canJoin && !data.joined) ...[
                        SizedBox(height: 10.dp),
                        Text(
                          'marketplace_verified_join_hint'.tr,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 12.sp,
                            height: 1.35,
                          ),
                        ),
                      ],
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

  Widget _sectionTitle(AppColors c, String text) {
    return Text(
      text,
      style: TextStyle(
        color: c.textPrimary,
        fontSize: 15.sp,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final AppColors c;
  final MarketplaceVerifiedGroupState state;
  final MarketplaceVerifiedGroupPreview data;

  const _HeaderCard({
    required this.c,
    required this.state,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final titleKey = 'marketplace_group_title_${data.slug}';
    final blurbKey = 'marketplace_group_blurb_${data.slug}';
    final title =
        titleKey.tr == titleKey ? (state.title.value.isNotEmpty ? state.title.value : data.title) : titleKey.tr;
    final blurb =
        blurbKey.tr == blurbKey ? (state.blurb.value.isNotEmpty ? state.blurb.value : data.blurb) : blurbKey.tr;

    return Container(
      padding: EdgeInsets.all(16.dp),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18.dp),
        border: Border.all(color: c.accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56.dp,
                height: 56.dp,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.accentSoft,
                  borderRadius: BorderRadius.circular(16.dp),
                ),
                child: Text(
                  state.emoji.value.isNotEmpty ? state.emoji.value : data.emoji,
                  style: TextStyle(fontSize: 26.sp),
                ),
              ),
              SizedBox(width: 12.dp),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.dp,
                            vertical: 4.dp,
                          ),
                          decoration: BoxDecoration(
                            color: c.accentSoft,
                            borderRadius: BorderRadius.circular(8.dp),
                          ),
                          child: Text(
                            '✔ ${'marketplace_verified_badge'.tr}',
                            style: TextStyle(
                              color: c.accent,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.dp),
                    Text(
                      'marketplace_group_meta'.trParams({
                        'members': '${data.memberCount}',
                        'rfq': '${data.rfqToday}',
                      }),
                      style: TextStyle(
                        color: c.textFaint,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (blurb.isNotEmpty) ...[
            SizedBox(height: 12.dp),
            Text(
              blurb,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 13.sp,
                height: 1.4,
              ),
            ),
          ],
          SizedBox(height: 12.dp),
          Text(
            'marketplace_verified_info_desc'.tr,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12.sp,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _MembersCard extends StatelessWidget {
  final AppColors c;
  final MarketplaceVerifiedGroupPreview data;

  const _MembersCard({required this.c, required this.data});

  @override
  Widget build(BuildContext context) {
    final remaining = data.memberCount - data.members.length;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16.dp),
        border: Border.all(color: c.surfaceBorder),
      ),
      child: Column(
        children: [
          for (var i = 0; i < data.members.length; i++) ...[
            if (i > 0) Divider(height: 1.dp, color: c.outline),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.dp, vertical: 10.dp),
              child: Row(
                children: [
                  ProfileAvatar(
                    initial: initialsOf(data.members[i].fullName),
                    gradient: avatarGradientFor(data.members[i].userId),
                    imageUrl: data.members[i].avatarUrl,
                    size: 40,
                    online: data.members[i].isOnline,
                  ),
                  SizedBox(width: 10.dp),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.members[i].fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (data.members[i].verifiedBadge)
                          Text(
                            'marketplace_verified_badge'.tr,
                            style: TextStyle(
                              color: c.accent,
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
          if (remaining > 0) ...[
            Divider(height: 1.dp, color: c.outline),
            Padding(
              padding: EdgeInsets.all(12.dp),
              child: Text(
                'marketplace_verified_members_more'.trParams({
                  'n': '$remaining',
                }),
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrustCard extends StatelessWidget {
  final AppColors c;
  final MarketplaceVerifiedGroupPreview data;
  final VoidCallback? onTap;

  const _TrustCard({required this.c, required this.data, this.onTap});

  @override
  Widget build(BuildContext context) {
    final pct = data.trustScore.clamp(0, 100);
    final radius = BorderRadius.circular(18.dp);
    final body = Container(
      padding: EdgeInsets.all(16.dp),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: radius,
        border: Border.all(color: c.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_outlined, color: c.accent, size: 22.dp),
              SizedBox(width: 8.dp),
              Expanded(
                child: Text(
                  'marketplace_verified_trust_title'.tr,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$pct%',
                style: TextStyle(
                  color: c.accentText,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.dp),
          ClipRRect(
            borderRadius: BorderRadius.circular(99.dp),
            child: Stack(
              children: [
                Container(height: 10.dp, color: c.outline.withValues(alpha: 0.35)),
                FractionallySizedBox(
                  widthFactor: pct / 100,
                  child: Container(
                    height: 10.dp,
                    decoration: const BoxDecoration(
                      gradient: limeButtonGradient,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12.dp),
          Text(
            data.documentsVerified
                ? 'marketplace_verified_trust_ready'.tr
                : 'marketplace_verified_trust_need_docs'.trParams({
                    'n': '$pct',
                  }),
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 13.sp,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: body,
      ),
    );
  }
}
