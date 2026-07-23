import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../ui/app_empty_state.dart';
import '../../ui/app_loading.dart';
import '../../ui/buttons/primary_button.dart';
import '../../ui/buttons/secondary_button.dart';
import '../../ui/items/info_row.dart';
import '../../ui/items/pill_badge.dart';
import '../../ui/items/profile_stat_card.dart';
import '../../ui/profile_avatar.dart';
import '../../ui/theme/colors.dart';
import '../../utils/formatters/time_formatter.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import 'profile_account.dart';
import 'profile_action.dart';
import 'profile_state.dart';

/// S14 — o'z profili. `isBusiness`ga qarab shaxsiy (obuna) yoki biznes
/// (e'lonlar/statistika) ko'rinishi ko'rsatiladi.
class ProfileContent extends ScreenContent<ProfileState> {
  ProfileContent() : super(color: Colors.transparent);

  @override
  Widget build(BuildContext context, ProfileState state,
      void Function(MyAction action) sendAction) {
    final c = context.appColors;

    return Padding(
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

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20.dp, 8.dp, 20.dp, 24.dp),
          child: Column(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  customBorder: d.isBusiness
                      ? RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22.dp),
                        )
                      : const CircleBorder(),
                  onTap: (d.avatarUrl?.trim().isNotEmpty == true)
                      ? () => sendAction(OpenProfileAvatar())
                      : null,
                  child: ProfileAvatar(
                    initial: d.initial,
                    gradient: d.avatarGradient,
                    imageUrl: d.avatarUrl,
                    shape: d.isBusiness
                        ? ProfileAvatarShape.roundedSquare
                        : ProfileAvatarShape.circle,
                  ),
                ),
              ),
              SizedBox(height: 14.dp),
              _nameRow(c, d),
              SizedBox(height: 6.dp),
              _subtitleRow(c, d),
              if (d.isBusiness) ...[
                SizedBox(height: 12.dp),
                PillBadge(
                  label: 'profile_business'.tr,
                  background: c.accentSoft,
                  foreground: c.accentText,
                  borderColor: c.accent,
                  fontSize: 12,
                ),
              ],
              SizedBox(height: 18.dp),
              if (d.isBusiness) _statsRow(c, d) else _infoCard(c, d),
              SizedBox(height: 18.dp),
              d.isBusiness
                  ? _businessActions(c, sendAction)
                  : _personalActions(c, sendAction),
              if (d.isBusiness) ...[
                SizedBox(height: 22.dp),
                _listingsSection(c, d, sendAction),
              ],
            ],
          ),
        );
      }),
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

  Widget _subtitleRow(AppColors c, ProfileAccount d) {
    final roleKey = d.roleLabel;
    final roleText = roleKey.isEmpty ? '' : roleKey.tr;
    final subtitle = d.isBusiness
        ? (roleText.isEmpty ? d.country : '${d.country} · $roleText')
        : (d.username == null || d.username!.isEmpty
            ? d.country
            : '${d.country} · ${d.username}');

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3.dp),
          child: Image.asset(
            d.flagAsset,
            width: 18.dp,
            height: 13.dp,
            fit: BoxFit.cover,
          ),
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

  Widget _statsRow(AppColors c, ProfileAccount d) {
    final listings = '${d.listingsCount ?? 0}';
    final views = (d.viewsCount == null || d.viewsCount!.isEmpty)
        ? '0'
        : d.viewsCount!;
    final rating = d.rating == null ? '—' : d.rating!.toStringAsFixed(1);
    return Row(
      children: [
        Expanded(
          child: ProfileStatCard(
            value: listings,
            label: 'profile_listings_stat'.tr,
          ),
        ),
        SizedBox(width: 10.dp),
        Expanded(
          child: ProfileStatCard(value: views, label: 'profile_views'.tr),
        ),
        SizedBox(width: 10.dp),
        Expanded(
          child: ProfileStatCard(value: rating, label: 'profile_rating'.tr),
        ),
      ],
    );
  }

  Widget _personalActions(AppColors c, void Function(MyAction) sendAction) {
    return Column(
      children: [
        PrimaryButton(
          text: 'profile_plans'.tr,
          startIcon: const Icon(
            Icons.workspace_premium_rounded,
            color: kNavy,
            size: 18,
          ),
          onTap: () => sendAction(OpenSubscription()),
        ),
        SizedBox(height: 12.dp),
        SecondaryButton(
          text: 'profile_edit'.tr,
          startIcon: Icon(Icons.edit_outlined, size: 18.dp),
          onTap: () => sendAction(EditPersonalProfile()),
        ),
        SizedBox(height: 18.dp),
        _settingsHub(c, sendAction),
      ],
    );
  }

  Widget _businessActions(AppColors c, void Function(MyAction) sendAction) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                text: 'profile_edit'.tr,
                startIcon: Icon(Icons.edit_outlined, size: 18.dp),
                onTap: () => sendAction(EditBusinessInfo()),
              ),
            ),
            SizedBox(width: 10.dp),
            Expanded(
              child: PrimaryButton(
                text: 'profile_add_product'.tr,
                startIcon: const Icon(
                  Icons.add_rounded,
                  color: kNavy,
                  size: 20,
                ),
                onTap: () => sendAction(AddProductRequested()),
              ),
            ),
          ],
        ),
        SizedBox(height: 12.dp),
        SecondaryButton(
          text: 'profile_plans'.tr,
          startIcon: Icon(Icons.workspace_premium_outlined, size: 18.dp),
          onTap: () => sendAction(OpenSubscription()),
        ),
        SizedBox(height: 18.dp),
        _settingsHub(c, sendAction),
      ],
    );
  }

  Widget _settingsHub(AppColors c, void Function(MyAction) sendAction) {
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
        _settingsTile(
          c,
          icon: Icons.tune_rounded,
          title: 'settings_app_title'.tr,
          subtitle: 'settings_app_desc'.tr,
          onTap: () => sendAction(OpenAppSettings()),
        ),
        SizedBox(height: 10.dp),
        _settingsTile(
          c,
          icon: Icons.manage_accounts_rounded,
          title: 'settings_account_title'.tr,
          subtitle: 'settings_account_desc'.tr,
          onTap: () => sendAction(OpenAccountSettings()),
        ),
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
    final count = d.listingsCount ?? d.listings.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '${'profile_my_listings'.tr} · $count',
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
              ),
          ],
        ),
        SizedBox(height: 12.dp),
        if (d.listings.isEmpty)
          Column(
            children: [
              AppEmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'profile_listings_empty'.tr,
                subtitle: 'profile_listings_empty_hint'.tr,
              ),
              SizedBox(height: 12.dp),
              SecondaryButton(
                text: 'profile_add_product'.tr,
                startIcon: Icon(Icons.add_rounded, size: 18.dp),
                onTap: () => sendAction(AddProductRequested()),
              ),
            ],
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
