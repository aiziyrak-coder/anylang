import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/core/country_names.dart';
import '../../../data/core/mappers.dart';
import '../../ui/app_empty_state.dart';
import '../../ui/app_loading.dart';
import '../../ui/app_top_bar.dart';
import '../../ui/gradient_background.dart';
import '../../ui/profile_avatar.dart';
import '../../ui/theme/colors.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import 'group_stats_action.dart';
import 'group_stats_state.dart';

class GroupStatsContent extends ScreenContent<GroupStatsState> {
  @override
  Widget build(
    BuildContext context,
    GroupStatsState state,
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
                title: 'group_stats_title'.tr,
                onBack: () => sendAction(Back()),
              ),
            ),
            Expanded(
              child: Obx(() {
                if (state.loading.value) {
                  return const Center(child: AppLoading());
                }
                final data = state.data.value;
                if (data == null) {
                  return AppEmptyState(
                    icon: Icons.insights_outlined,
                    title: 'group_stats_empty'.tr,
                    subtitle: 'group_stats_empty_hint'.tr,
                  );
                }
                return RefreshIndicator(
                  color: c.accent,
                  onRefresh: () async { await sendAction(GroupStatsRefresh()); },
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(16.dp, 8.dp, 16.dp, 24.dp),
                    children: [
                      Text(
                        'group_stats_meta'.trParams({
                          'members': '${data.memberCount}',
                          'messages': '${data.messageCount}',
                        }),
                        style: TextStyle(
                          color: c.textFaint,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 14.dp),
                      _HeroCard(
                        emoji: '🌍',
                        title: 'group_stats_top_country'.tr,
                        value: data.topCountry == null
                            ? 'group_stats_none'.tr
                            : resolveCountryName(data.topCountry!.code),
                        subtitle: data.topCountry == null
                            ? null
                            : 'group_stats_country_sub'.trParams({
                                'messages': '${data.topCountry!.messageCount}',
                                'members': '${data.topCountry!.memberCount}',
                              }),
                      ),
                      SizedBox(height: 10.dp),
                      _HeroCard(
                        emoji: '🏭',
                        title: 'group_stats_top_company'.tr,
                        value: data.topCompany?.companyName ??
                            'group_stats_none'.tr,
                        subtitle: data.topCompany == null
                            ? null
                            : 'group_stats_company_sub'.trParams({
                                'n': '${data.topCompany!.messageCount}',
                              }),
                        onTap: data.topCompany == null
                            ? null
                            : () => sendAction(
                                  GroupStatsOpenUser(data.topCompany!.userId),
                                ),
                        logoUrl: data.topCompany?.logoUrl,
                        userId: data.topCompany?.userId,
                      ),
                      SizedBox(height: 10.dp),
                      _HeroCard(
                        emoji: '📦',
                        title: 'group_stats_top_products'.tr,
                        value: data.topProducts?.companyName ??
                            'group_stats_none'.tr,
                        subtitle: data.topProducts == null
                            ? null
                            : 'group_stats_products_sub'.trParams({
                                'products':
                                    '${data.topProducts!.productCount}',
                                'shared':
                                    '${data.topProducts!.sharedInChat}',
                              }),
                        onTap: data.topProducts == null
                            ? null
                            : () => sendAction(
                                  GroupStatsOpenUser(data.topProducts!.userId),
                                ),
                        logoUrl: data.topProducts?.logoUrl,
                        userId: data.topProducts?.userId,
                      ),
                      SizedBox(height: 10.dp),
                      _HeroCard(
                        emoji: '🤝',
                        title: 'group_stats_top_deals'.tr,
                        value: data.topDeals?.companyName ??
                            'group_stats_none'.tr,
                        subtitle: data.topDeals == null
                            ? null
                            : 'group_stats_deals_sub'.trParams({
                                'n': '${data.topDeals!.dealCount}',
                              }),
                        onTap: data.topDeals == null
                            ? null
                            : () => sendAction(
                                  GroupStatsOpenUser(data.topDeals!.userId),
                                ),
                        logoUrl: data.topDeals?.logoUrl,
                        userId: data.topDeals?.userId,
                      ),
                      if (data.companies.length > 1) ...[
                        SizedBox(height: 20.dp),
                        Text(
                          'group_stats_leaders_companies'.tr,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 8.dp),
                        for (var i = 0; i < data.companies.length; i++) ...[
                          _LeaderRow(
                            rank: i + 1,
                            title: data.companies[i].companyName,
                            subtitle: 'group_stats_company_sub'.trParams({
                              'n': '${data.companies[i].messageCount}',
                            }),
                            logoUrl: data.companies[i].logoUrl,
                            userId: data.companies[i].userId,
                            onTap: () => sendAction(
                              GroupStatsOpenUser(data.companies[i].userId),
                            ),
                          ),
                          if (i < data.companies.length - 1)
                            SizedBox(height: 8.dp),
                        ],
                      ],
                      if (data.countries.length > 1) ...[
                        SizedBox(height: 20.dp),
                        Text(
                          'group_stats_leaders_countries'.tr,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 8.dp),
                        for (var i = 0; i < data.countries.length; i++) ...[
                          _LeaderRow(
                            rank: i + 1,
                            title: resolveCountryName(data.countries[i].code),
                            subtitle: 'group_stats_country_sub'.trParams({
                              'messages':
                                  '${data.countries[i].messageCount}',
                              'members': '${data.countries[i].memberCount}',
                            }),
                          ),
                          if (i < data.countries.length - 1)
                            SizedBox(height: 8.dp),
                        ],
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
}

class _HeroCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String value;
  final String? subtitle;
  final VoidCallback? onTap;
  final String? logoUrl;
  final int? userId;

  const _HeroCard({
    required this.emoji,
    required this.title,
    required this.value,
    this.subtitle,
    this.onTap,
    this.logoUrl,
    this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final card = Container(
      padding: EdgeInsets.all(14.dp),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16.dp),
        border: Border.all(color: c.surfaceBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44.dp,
            height: 44.dp,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.accentSoft,
              borderRadius: BorderRadius.circular(12.dp),
            ),
            child: Text(emoji, style: TextStyle(fontSize: 20.sp)),
          ),
          SizedBox(width: 12.dp),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: c.textFaint,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                SizedBox(height: 4.dp),
                Row(
                  children: [
                    if (userId != null) ...[
                      ProfileAvatar(
                        initial: initialsOf(value),
                        gradient: avatarGradientFor(userId!),
                        size: 28,
                        imageUrl: logoUrl,
                      ),
                      SizedBox(width: 8.dp),
                    ],
                    Expanded(
                      child: Text(
                        value,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  SizedBox(height: 4.dp),
                  Text(
                    subtitle!,
                    style: TextStyle(color: c.textSecondary, fontSize: 12.sp),
                  ),
                ],
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right_rounded, color: c.textFaint, size: 20.dp),
        ],
      ),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.dp),
        child: card,
      ),
    );
  }
}

class _LeaderRow extends StatelessWidget {
  final int rank;
  final String title;
  final String subtitle;
  final String? logoUrl;
  final int? userId;
  final VoidCallback? onTap;

  const _LeaderRow({
    required this.rank,
    required this.title,
    required this.subtitle,
    this.logoUrl,
    this.userId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final row = Container(
      padding: EdgeInsets.symmetric(horizontal: 12.dp, vertical: 10.dp),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12.dp),
        border: Border.all(color: c.surfaceBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24.dp,
            child: Text(
              '$rank',
              style: TextStyle(
                color: c.accent,
                fontSize: 14.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (userId != null) ...[
            ProfileAvatar(
              initial: initialsOf(title),
              gradient: avatarGradientFor(userId!),
              size: 32,
              imageUrl: logoUrl,
            ),
            SizedBox(width: 10.dp),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: c.textFaint, fontSize: 11.sp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.dp),
        child: row,
      ),
    );
  }
}
