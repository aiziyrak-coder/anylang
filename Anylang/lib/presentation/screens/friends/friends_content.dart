import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../data/core/country_names.dart';
import '../../ui/app_empty_state.dart';
import '../../ui/app_loading.dart';
import '../../ui/buttons/my_icon_button.dart';
import '../../ui/items/friend_recommendation_item.dart';
import '../../ui/items/profile_viewer_item.dart';
import '../../ui/items/user_card_item.dart';
import '../../ui/search_field.dart';
import '../../ui/theme/colors.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import 'friend.dart';
import 'friends_action.dart';
import 'friends_state.dart';

class FriendsContent extends ScreenContent<FriendsState> {
  FriendsContent() : super(color: Colors.transparent);

  late final TextEditingController _searchCtrl;

  @override
  void initContent() {
    _searchCtrl = TextEditingController();
  }

  @override
  void onClose() {
    _searchCtrl.dispose();
  }

  @override
  Widget build(BuildContext context, FriendsState state, FutureOr<void> Function(MyAction action) sendAction) {
    final c = context.appColors;

    return Padding(
      padding: EdgeInsets.only(top: 8.dp),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.dp),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'friends_title'.tr,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 27.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Obx(() {
                  final count = state.pendingCount.value;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      MyIconButton(
                        onClick: () => sendAction(OpenFriendRequests()),
                        icon: Icons.mail_outline_rounded,
                        iconColor: c.textPrimary,
                        iconSize: 22.dp,
                        backgroundColor: c.surface,
                        borderRadius: 12.dp,
                        padding: EdgeInsets.all(10.dp),
                      ),
                      if (count > 0)
                        Positioned(
                          right: -4.dp,
                          top: -4.dp,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 5.dp, vertical: 1.dp),
                            decoration: BoxDecoration(
                              color: c.accent,
                              borderRadius: BorderRadius.circular(99.dp),
                            ),
                            constraints: BoxConstraints(minWidth: 18.dp, minHeight: 18.dp),
                            alignment: Alignment.center,
                            child: Text(
                              count > 99 ? '99+' : '$count',
                              style: TextStyle(
                                color: c.onAccent,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                }),
                SizedBox(width: 8.dp),
                MyIconButton(
                  onClick: () => sendAction(AddFriend()),
                  icon: Icons.person_add_alt_1,
                  iconColor: c.onAccent,
                  iconSize: 20.dp,
                  backgroundColor: c.accent,
                  borderRadius: 12.dp,
                  padding: EdgeInsets.all(10.dp),
                ),
              ],
            ),
          ),
          Expanded(
            child: Obx(() {
              final header = <Widget>[
                Padding(
                  padding: EdgeInsets.fromLTRB(20.dp, 12.dp, 20.dp, 0),
                  child: SearchField(
                    key: const ValueKey('friends_search'),
                    hint: 'friends_search_hint'.tr,
                    controller: _searchCtrl,
                    onChanged: (v) => sendAction(FriendsSearchChanged(v)),
                  ),
                ),
                SizedBox(height: 10.dp),
                _filtersRow(c, state, sendAction),
                SizedBox(height: 8.dp),
              ];

              if (state.loading.value) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    ...header,
                    SizedBox(height: 48.dp),
                    const AppLoading(),
                  ],
                );
              }

              final q = state.query.value.trim().toLowerCase();
              final filtered = state.friends.where((f) => _matches(f, state, q)).toList();
              final onlineOnly = state.filterOnline.value;
              final online = filtered.where((f) => f.online).toList();
              final others = onlineOnly
                  ? <Friend>[]
                  : filtered.where((f) => !f.online).toList();
              final onlineVisible = online;
              final recs = state.recommendations.toList();
              final recsFailed = state.recommendationsLoadFailed.value;
              final showRecs =
                  q.isEmpty && !state.hasActiveFilters && recs.isNotEmpty;
              final showRecsFailed =
                  q.isEmpty && !state.hasActiveFilters && recsFailed;
              final viewers = state.profileViewers.toList();
              final viewersTotal = state.profileViewersTotal.value;
              final viewersLocked = state.profileViewersLocked.value;
              final showViewers = q.isEmpty &&
                  !state.hasActiveFilters &&
                  (viewers.isNotEmpty ||
                      (viewersLocked && viewersTotal > 0));

              if (onlineVisible.isEmpty &&
                  others.isEmpty &&
                  !showRecs &&
                  !showRecsFailed &&
                  !showViewers) {
                final noFilters = q.isEmpty && !state.hasActiveFilters;
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    ...header,
                    SizedBox(
                      height: 320.dp,
                      child: AppEmptyState(
                        icon: noFilters
                            ? Icons.people_outline_rounded
                            : Icons.search_off_rounded,
                        title: noFilters
                            ? 'friends_empty'.tr
                            : 'empty_no_results'.tr,
                        subtitle: noFilters ? 'friends_empty_hint'.tr : null,
                      ),
                    ),
                  ],
                );
              }

              final children = <Widget>[...header];
              if (showRecs) {
                final matchCount = state.recommendationTotalCount.value > 0
                    ? state.recommendationTotalCount.value
                    : recs.length;
                children.add(
                  Padding(
                    padding: EdgeInsets.fromLTRB(20.dp, 4.dp, 20.dp, 4.dp),
                    child: Text(
                      'business_match_title'.tr,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                );
                children.add(
                  Padding(
                    padding: EdgeInsets.fromLTRB(20.dp, 0, 20.dp, 8.dp),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.dp,
                        vertical: 12.dp,
                      ),
                      decoration: BoxDecoration(
                        color: c.accentSoft,
                        borderRadius: BorderRadius.circular(14.dp),
                        border: Border.all(
                          color: c.accent.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('✨', style: TextStyle(fontSize: 16.sp)),
                          SizedBox(width: 8.dp),
                          Expanded(
                            child: Text(
                              'business_match_ai_banner'.trParams({
                                'n': '$matchCount',
                              }),
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
                children.add(
                  SizedBox(
                    height: 188.dp,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.fromLTRB(20.dp, 4.dp, 20.dp, 8.dp),
                      itemCount: recs.length,
                      separatorBuilder: (_, __) => SizedBox(width: 10.dp),
                      itemBuilder: (_, i) {
                        final item = recs[i];
                        return FriendRecommendationItem(
                          item: item,
                          onChat: () => sendAction(OpenRecommendedChat(item)),
                        );
                      },
                    ),
                  ),
                );
              }
              if (showRecsFailed) {
                children.add(
                  Padding(
                    padding: EdgeInsets.fromLTRB(20.dp, 8.dp, 20.dp, 8.dp),
                    child: Text(
                      'friends_recommendations_failed'.tr,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }
              if (showViewers) {
                children.add(
                  Padding(
                    padding: EdgeInsets.fromLTRB(20.dp, 8.dp, 20.dp, 4.dp),
                    child: Text(
                      'profile_viewers_title'.tr,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                );
                if (viewersLocked) {
                  children.add(
                    Padding(
                      padding: EdgeInsets.fromLTRB(20.dp, 0, 20.dp, 8.dp),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () =>
                              sendAction(OpenProfileViewersPremium()),
                          borderRadius: BorderRadius.circular(14.dp),
                          child: Ink(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              horizontal: 14.dp,
                              vertical: 14.dp,
                            ),
                            decoration: BoxDecoration(
                              color: c.surface,
                              borderRadius: BorderRadius.circular(14.dp),
                              border: Border.all(color: c.surfaceBorder),
                            ),
                            child: Row(
                              children: [
                                Text('🔒', style: TextStyle(fontSize: 20.sp)),
                                SizedBox(width: 10.dp),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'profile_viewers_locked_banner'
                                            .trParams({
                                          'n': '$viewersTotal',
                                        }),
                                        style: TextStyle(
                                          color: c.textPrimary,
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w700,
                                          height: 1.3,
                                        ),
                                      ),
                                      SizedBox(height: 4.dp),
                                      Text(
                                        'profile_viewers_premium_cta'.tr,
                                        style: TextStyle(
                                          color: c.accent,
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                } else {
                  children.add(
                    SizedBox(
                      height: 132.dp,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding:
                            EdgeInsets.fromLTRB(20.dp, 4.dp, 20.dp, 8.dp),
                        itemCount: viewers.length,
                        separatorBuilder: (_, __) => SizedBox(width: 10.dp),
                        itemBuilder: (_, i) {
                          final item = viewers[i];
                          return ProfileViewerItem(
                            item: item,
                            onTap: () =>
                                sendAction(OpenProfileViewer(item)),
                          );
                        },
                      ),
                    ),
                  );
                }
              }
              if (onlineVisible.isEmpty && others.isEmpty) {
                children.add(
                  Padding(
                    padding: EdgeInsets.fromLTRB(20.dp, 20.dp, 20.dp, 8.dp),
                    child: Column(
                      children: [
                        Icon(
                          Icons.people_outline_rounded,
                          size: 40.dp,
                          color: c.textFaint,
                        ),
                        SizedBox(height: 10.dp),
                        Text(
                          'friends_empty'.tr,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4.dp),
                        Text(
                          'friends_empty_hint'.tr,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 13.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              } else {
                if (onlineVisible.isNotEmpty) {
                  children.add(
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.dp),
                      child: _sectionHeader(
                        c,
                        'friends_section_online'.trParams({
                          'n': '${onlineVisible.length}',
                        }),
                      ),
                    ),
                  );
                  children.addAll(
                    onlineVisible.map(
                      (f) => Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.dp),
                        child: _item(f, sendAction),
                      ),
                    ),
                  );
                }
                if (others.isNotEmpty) {
                  children.add(
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.dp),
                      child: _sectionHeader(
                        c,
                        'friends_section_all'.trParams({
                          'n': '${others.length}',
                        }),
                      ),
                    ),
                  );
                  children.addAll(
                    others.map(
                      (f) => Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.dp),
                        child: _item(f, sendAction),
                      ),
                    ),
                  );
                }
              }

              return RefreshIndicator(
                onRefresh: () async { await sendAction(RefreshFriends()); },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(bottom: 12.dp),
                  children: children,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  bool _matches(Friend f, FriendsState state, String q) {
    if (q.isNotEmpty && !f.name.toLowerCase().contains(q)) return false;
    final country = state.filterCountry.value;
    if (country != null &&
        (f.country ?? '').trim().toUpperCase() != country.toUpperCase()) {
      return false;
    }
    final role = state.filterRole.value;
    if (role != null &&
        (f.businessRole ?? '').trim().toLowerCase() != role.toLowerCase()) {
      return false;
    }
    final product = state.filterProduct.value;
    if (product != null) {
      final code = product.toLowerCase();
      final hasCat = f.productCategories.any((c) => c.toLowerCase() == code);
      final hasKw = f.keywords.any((k) => k.toLowerCase().contains(code));
      if (!hasCat && !hasKw) return false;
    }
    if (state.filterVerified.value && !f.verified) return false;
    if (state.filterOnline.value && !f.online) return false;
    return true;
  }

  Widget _filtersRow(
    AppColors c,
    FriendsState state,
    void Function(MyAction) sendAction,
  ) {
    return Obx(() {
      final country = state.filterCountry.value;
      final role = state.filterRole.value;
      final product = state.filterProduct.value;
      final verified = state.filterVerified.value;
      final online = state.filterOnline.value;

      final countryLabel = country == null
          ? 'friends_filter_country'.tr
          : '🌍 ${resolveCountryName(country)}';
      final roleLabel = role == null
          ? 'friends_filter_industry'.tr
          : '🏭 ${'business_role_$role'.tr}';
      String productLabel = 'friends_filter_product'.tr;
      if (product != null) {
        final match = state.productCategories.where(
          (e) => e.code.toLowerCase() == product.toLowerCase(),
        );
        final title = match.isEmpty ? product : match.first.title;
        productLabel = '📦 $title';
      }

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20.dp),
        child: Row(
          children: [
            _chip(
              c,
              label: countryLabel,
              selected: country != null,
              onTap: () => sendAction(FriendsPickCountry()),
              onClear: country == null
                  ? null
                  : () => sendAction(FriendsSelectCountry(null)),
            ),
            SizedBox(width: 8.dp),
            _chip(
              c,
              label: roleLabel,
              selected: role != null,
              onTap: () => sendAction(FriendsPickRole()),
              onClear:
                  role == null ? null : () => sendAction(FriendsSelectRole(null)),
            ),
            SizedBox(width: 8.dp),
            _chip(
              c,
              label: productLabel,
              selected: product != null,
              onTap: () => sendAction(FriendsPickProduct()),
              onClear: product == null
                  ? null
                  : () => sendAction(FriendsSelectProduct(null)),
            ),
            SizedBox(width: 8.dp),
            _chip(
              c,
              label: 'friends_filter_verified'.tr,
              selected: verified,
              onTap: () => sendAction(FriendsToggleVerified()),
            ),
            SizedBox(width: 8.dp),
            _chip(
              c,
              label: 'friends_filter_online'.tr,
              selected: online,
              onTap: () => sendAction(FriendsToggleOnline()),
            ),
            if (state.hasActiveFilters) ...[
              SizedBox(width: 8.dp),
              _chip(
                c,
                label: 'friends_filter_clear'.tr,
                selected: false,
                onTap: () => sendAction(FriendsClearFilters()),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _chip(
    AppColors c, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
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
            border: Border.all(
              color: selected ? c.accent : c.surfaceBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? c.onAccent : c.textPrimary,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (onClear != null) ...[
                SizedBox(width: 4.dp),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onClear();
                  },
                  child: Icon(
                    Icons.close_rounded,
                    size: 14.dp,
                    color: selected ? c.onAccent : c.textFaint,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(AppColors c, String label) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12.dp, 14.dp, 12.dp, 6.dp),
      child: Text(
        label,
        style: TextStyle(
          color: c.textPrimary,
          fontSize: 14.sp,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _item(Friend f, void Function(MyAction) sendAction) {
    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        sendAction(RemoveFriend(f));
      },
      child: UserCardItem(
        initial: f.initial,
        avatarGradient: f.avatarGradient,
        avatarUrl: f.avatarUrl,
        name: f.name,
        online: f.online,
        lastSeenAt: f.lastSeenAt,
        country: f.country,
        businessRole: f.businessRole,
        keywords: f.keywords,
        isBusiness: f.isBusiness,
        rating: f.rating,
        reviewsCount: f.reviewsCount,
        trust: f.trust,
        riskLevel: f.riskLevel,
        isScammer: f.isScammer,
        verified: f.verified,
        languages: f.languages,
        productsCount: f.productsCount,
        countriesCount: f.countriesCount,
        showMessage: false,
        showAdd: false,
        showQuickActions: !f.isScammer &&
            !f.verified &&
            f.riskLevel != 'medium' &&
            f.riskLevel != 'high',
        onTap: () => sendAction(OpenFriendProfile(f)),
        onMessage: () => sendAction(OpenChat(f)),
        onCall: null,
        onLiveTranslate: () => sendAction(OpenFriendLive(f)),
        onProducts: () => sendAction(OpenFriendProducts(f)),
        onProfile: () => sendAction(OpenFriendProfile(f)),
      ),
    );
  }
}
