import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
/// (e'lonlar/statistika) ko'rinishi ko'rsatiladi. Asosiy ekranning "Profil"
/// tabi sifatida ishlatiladi — fon shaffof (MainContent gradienti ko'rinadi).
class ProfileContent extends ScreenContent<ProfileState> {

  ProfileContent() : super(color: Colors.transparent);

  @override
  Widget build(BuildContext context, ProfileState state, void Function(MyAction action) sendAction) {
    final c = context.appColors;

    return Padding(
      padding: EdgeInsets.only(top: 8.dp),
      child: Obx(() {
        final d = state.account.value;
        if (d == null) return const SizedBox.shrink();

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20.dp, 8.dp, 20.dp, 24.dp),
          child: Column(
            children: [
              ProfileAvatar(
                initial: d.initial,
                gradient: d.avatarGradient,
                shape: d.isBusiness ? ProfileAvatarShape.roundedSquare : ProfileAvatarShape.circle,
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
              d.isBusiness ? _businessActions(sendAction) : _personalActions(sendAction),
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
            style: TextStyle(color: c.textPrimary, fontSize: 22.sp, fontWeight: FontWeight.w700),
          ),
        ),
        if (d.verified) ...[
          SizedBox(width: 6.dp),
          Icon(Icons.verified_rounded, size: 20.dp, color: c.accentText),
        ],
        if (!d.isBusiness && d.subscriptionPlan != null) ...[
          SizedBox(width: 8.dp),
          PillBadge(
            label: d.subscriptionPlan!.toUpperCase(),
            icon: Icons.workspace_premium_rounded,
            background: c.accent,
            foreground: c.onAccent,
          ),
        ],
      ],
    );
  }

  Widget _subtitleRow(AppColors c, ProfileAccount d) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3.dp),
          child: Image.asset(d.flagAsset, width: 18.dp, height: 13.dp, fit: BoxFit.cover),
        ),
        SizedBox(width: 6.dp),
        Text(
          d.isBusiness ? '${d.country} · ${d.role}' : '${d.country} · ${d.username}',
          style: TextStyle(color: c.textSecondary, fontSize: 13.sp),
        ),
      ],
    );
  }

  Widget _infoCard(AppColors c, ProfileAccount d) {
    final rows = <Widget>[
      InfoRow(icon: Icons.language_outlined, label: 'profile_native_language'.tr, value: d.nativeLanguage ?? ''),
      InfoRow(icon: Icons.location_on_outlined, label: 'profile_country'.tr, value: d.country),
      InfoRow(icon: Icons.calendar_today_outlined, label: 'profile_member_since'.tr, value: d.memberSince ?? ''),
      InfoRow(
        icon: Icons.workspace_premium_outlined,
        label: 'profile_subscription'.tr,
        value: '${d.subscriptionPlan} · ${d.subscriptionPeriod}',
        valueColor: c.accentText,
      ),
      if (d.subscriptionExpiresAt != null)
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
        children.add(Divider(height: 1.dp, thickness: 1.dp, color: c.outline));
      }
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16.dp),
        border: Border.all(color: c.outline),
      ),
      child: Column(children: children),
    );
  }

  Widget _statsRow(AppColors c, ProfileAccount d) {
    return Row(
      children: [
        Expanded(child: ProfileStatCard(value: '${d.listingsCount}', label: 'profile_listings_stat'.tr)),
        SizedBox(width: 10.dp),
        Expanded(child: ProfileStatCard(value: d.viewsCount ?? '', label: 'profile_views'.tr)),
        SizedBox(width: 10.dp),
        Expanded(child: ProfileStatCard(value: '${d.rating}', label: 'profile_rating'.tr)),
      ],
    );
  }

  Widget _personalActions(void Function(MyAction) sendAction) {
    return Column(
      children: [
        PrimaryButton(
          text: 'profile_plans'.tr,
          startIcon: const Icon(Icons.workspace_premium_rounded, color: kNavy, size: 18),
          onTap: () => sendAction(OpenSubscription()),
        ),
        SizedBox(height: 12.dp),
        SecondaryButton(
          text: 'profile_edit'.tr,
          startIcon: Icon(Icons.edit_outlined, size: 18.dp),
          onTap: () => sendAction(EditPersonalProfile()),
        ),
        SizedBox(height: 12.dp),
        SecondaryButton(
          text: 'profile_settings'.tr,
          startIcon: Icon(Icons.settings_outlined, size: 18.dp),
          onTap: () => sendAction(OpenSettings()),
        ),
      ],
    );
  }

  Widget _businessActions(void Function(MyAction) sendAction) {
    return Row(
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
            startIcon: const Icon(Icons.add_rounded, color: kNavy, size: 20),
            onTap: () => sendAction(AddProductRequested()),
          ),
        ),
      ],
    );
  }

  Widget _listingsSection(AppColors c, ProfileAccount d, void Function(MyAction) sendAction) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '${'profile_my_listings'.tr} · ${d.listingsCount}',
              style: TextStyle(color: c.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            InkWell(
              onTap: () => sendAction(SeeAllListings()),
              child: Text(
                'products_see_all'.tr,
                style: TextStyle(color: c.accentText, fontSize: 13.sp, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        SizedBox(height: 12.dp),
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
          itemCount: d.listings.length,
          itemBuilder: (_, i) => _ownListingCard(c, d.listings[i], sendAction),
        ),
      ],
    );
  }

  Widget _ownListingCard(AppColors c, OwnListing listing, void Function(MyAction) sendAction) {
    final radius = BorderRadius.circular(16.dp);
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
              child: DecoratedBox(decoration: BoxDecoration(gradient: listing.tileGradient)),
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
                    style: TextStyle(color: c.textPrimary, fontSize: 13.sp, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 4.dp),
                  Text(
                    listing.price,
                    style: TextStyle(color: c.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w700),
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
