import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import '../../ui/app_empty_state.dart';
import '../../ui/app_top_bar.dart';
import '../../ui/buttons/my_icon_button.dart';
import '../../ui/buttons/rich_button.dart';
import '../../ui/gradient_background.dart';
import '../../ui/items/info_row.dart';
import '../../ui/items/pill_badge.dart';
import '../../ui/items/product_grid_card.dart';
import '../../ui/profile_avatar.dart';
import '../../ui/theme/colors.dart';
import '../../ui/theme/gradients.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import 'user_profile_action.dart';
import 'user_profile_payload.dart';
import 'user_profile_state.dart';

class UserProfileContent extends ScreenContent<UserProfileState> {

  @override
  Widget build(BuildContext context, UserProfileState state, void Function(MyAction action) sendAction) {
    final c = context.appColors;
    final d = state.data;

    return GradientBackground(
      child: SafeArea(
        child: d == null
            ? const SizedBox.shrink()
            : Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.dp, 4.dp, 16.dp, 0),
                    child: AppTopBar(title: 'profile_title'.tr, onBack: () => sendAction(Back())),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(16.dp, 8.dp, 16.dp, 24.dp),
                      child: Column(
                        children: [
                          _avatar(c, d),
                          SizedBox(height: 14.dp),
                          _nameRow(c, d),
                          SizedBox(height: 6.dp),
                          _subtitle(c, d),
                          if (d.business) ...[
                            SizedBox(height: 12.dp),
                            _businessBadge(c),
                          ],
                          SizedBox(height: 18.dp),
                          _actions(c, d, sendAction),
                          SizedBox(height: 18.dp),
                          _infoCard(c, d, sendAction),
                          if (d.business) ...[
                            SizedBox(height: 20.dp),
                            _completeness(c, d),
                            SizedBox(height: 20.dp),
                            _sectionTitle(c, 'profile_certificates'.tr),
                            SizedBox(height: 10.dp),
                            _certificates(c, d),
                            SizedBox(height: 20.dp),
                            _sectionTitle(c, 'profile_factory_images'.tr),
                            SizedBox(height: 10.dp),
                            _factoryImages(),
                            SizedBox(height: 20.dp),
                            _sectionTitle(c, '${'profile_listings'.tr} · ${d.listings}'),
                            SizedBox(height: 12.dp),
                            _listings(state, sendAction),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _avatar(AppColors c, UserProfilePayload d) {
    return ProfileAvatar(
      initial: d.initial,
      gradient: d.avatarGradient,
      shape: d.business ? ProfileAvatarShape.roundedSquare : ProfileAvatarShape.circle,
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
        if (d.verified) ...[
          SizedBox(width: 6.dp),
          SvgPicture.asset('assets/icons/ic_verified.svg', width: 20.dp, height: 20.dp),
        ],
      ],
    );
  }

  Widget _subtitle(AppColors c, UserProfilePayload d) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3.dp),
          child: Image.asset(d.flagAsset, width: 18.dp, height: 13.dp, fit: BoxFit.cover),
        ),
        SizedBox(width: 6.dp),
        Text('${d.country} · ${d.role}', style: TextStyle(color: c.textSecondary, fontSize: 13.sp)),
      ],
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

  Widget _actions(AppColors c, UserProfilePayload d, void Function(MyAction) sendAction) {
    final radius = BorderRadius.circular(14.dp);
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
        SizedBox(width: 10.dp),
        MyIconButton(
          onClick: () => sendAction(CallUser()),
          svgIcon: 'assets/icons/ic_phone.svg',
          iconColor: c.textPrimary,
          iconSize: 20.dp,
          backgroundColor: c.surface,
          borderRadius: 14.dp,
          padding: EdgeInsets.all(14.dp),
          border: Border.all(color: c.outline),
        ),
        if (d.business) ...[
          SizedBox(width: 10.dp),
          MyIconButton(
            onClick: () => sendAction(OpenWebsite()),
            svgIcon: 'assets/icons/ic_globe.svg',
            iconColor: c.textPrimary,
            iconSize: 20.dp,
            backgroundColor: c.surface,
            borderRadius: 14.dp,
            padding: EdgeInsets.all(14.dp),
            border: Border.all(color: c.outline),
          ),
        ],
      ],
    );
  }

  Widget _infoCard(AppColors c, UserProfilePayload d, void Function(MyAction) sendAction) {
    final rows = <Widget>[
      InfoRow(iconAsset: 'assets/icons/ic_location.svg', label: 'profile_country'.tr, value: d.country),
      if (d.business) ...[
        InfoRow(iconAsset: 'assets/icons/ic_activity.svg', label: 'profile_activity'.tr, value: d.role),
        InfoRow(iconAsset: 'assets/icons/ic_clock.svg', label: 'profile_experience'.tr, value: d.experience ?? ''),
        InfoRow(
          iconAsset: 'assets/icons/ic_globe.svg',
          label: 'profile_website'.tr,
          value: d.website ?? '',
          valueColor: c.accentText,
          onTap: () => sendAction(OpenWebsite()),
        ),
      ],
      InfoRow(iconAsset: 'assets/icons/ic_phone.svg', label: 'profile_phone'.tr, value: d.phone),
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

  Widget _factoryImages() {
    Widget tile(LinearGradient g) => Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: g, borderRadius: BorderRadius.circular(14.dp)),
            child: Center(
              child: SvgPicture.asset('assets/icons/ic_prod_image.svg', width: 26.dp, height: 26.dp),
            ),
          ),
        );
    return SizedBox(
      height: 90.dp,
      child: Row(
        children: [
          tile(prodBlueGradient),
          SizedBox(width: 10.dp),
          tile(prodBrownGradient),
        ],
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
