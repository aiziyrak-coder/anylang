import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../ui/app_empty_state.dart';
import '../../ui/app_loading.dart';
import '../../ui/app_top_bar.dart';
import '../../ui/buttons/primary_button.dart';
import '../../ui/buttons/secondary_button.dart';
import '../../ui/items/nearby_user_item.dart';
import '../../ui/theme/colors.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import 'nearby_action.dart';
import 'nearby_state.dart';

class NearbyContent extends ScreenContent<NearbyState> {
  NearbyContent() : super(color: Colors.transparent);

  static const _langFilters = <String?>[
    null,
    'en',
    'ru',
    'uz',
    'tr',
    'zh',
    'ar',
    'de',
    'fr',
    'es',
    'ko',
    'ja',
  ];

  @override
  Widget build(
    BuildContext context,
    NearbyState state,
    FutureOr<void> Function(MyAction action) sendAction,
  ) {
    final c = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(8.dp, 4.dp, 12.dp, 0),
          child: AppTopBar(
            title: 'nearby_title'.tr,
            onBack: () => sendAction(BackFromNearby()),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20.dp, 4.dp, 20.dp, 0),
          child: Text(
            'nearby_subtitle'.tr,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 13.sp,
              height: 1.35,
            ),
          ),
        ),
        SizedBox(height: 12.dp),
        SizedBox(
          height: 38.dp,
          child: Obx(() {
            final selected = state.languageFilter.value;
            return ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 20.dp),
              itemCount: _langFilters.length,
              separatorBuilder: (_, _) => SizedBox(width: 8.dp),
              itemBuilder: (_, i) {
                final code = _langFilters[i];
                final active = selected == code;
                final label = code == null
                    ? 'nearby_lang_all'.tr
                    : 'nearby_lang_$code'.tr;
                return Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(999.dp),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => sendAction(SelectNearbyLanguage(code)),
                    borderRadius: BorderRadius.circular(999.dp),
                    child: Ink(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.dp,
                        vertical: 8.dp,
                      ),
                      decoration: BoxDecoration(
                        color: active ? c.accent : c.surface,
                        borderRadius: BorderRadius.circular(999.dp),
                        border: Border.all(
                          color: active ? c.accent : c.surfaceBorder,
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: active ? c.onAccent : c.textPrimary,
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ),
        SizedBox(height: 8.dp),
        Expanded(
          child: Obx(() {
            if (state.loading.value && state.people.isEmpty) {
              return const AppLoading();
            }
            if (state.permissionDenied.value) {
              return _centered(
                AppEmptyState(
                  icon: Icons.location_off_outlined,
                  title: 'nearby_permission_title'.tr,
                  subtitle: 'nearby_permission_desc'.tr,
                ),
                child: SecondaryButton(
                  text: 'nearby_permission_retry'.tr,
                  onTap: () => sendAction(RetryNearby()),
                ),
              );
            }
            if (state.locationServiceOff.value) {
              return _centered(
                AppEmptyState(
                  icon: Icons.gps_off_outlined,
                  title: 'nearby_gps_off'.tr,
                  subtitle: 'nearby_gps_off_hint'.tr,
                ),
                child: SecondaryButton(
                  text: 'nearby_permission_retry'.tr,
                  onTap: () => sendAction(RetryNearby()),
                ),
              );
            }
            if (state.gpsFailed.value) {
              return _centered(
                AppEmptyState(
                  icon: Icons.my_location_outlined,
                  title: 'nearby_gps_failed'.tr,
                  subtitle: 'nearby_gps_failed_hint'.tr,
                ),
                child: SecondaryButton(
                  text: 'common_retry'.tr,
                  onTap: () => sendAction(RetryNearby()),
                ),
              );
            }
            if (state.locked.value) {
              return _centered(
                AppEmptyState(
                  icon: Icons.workspace_premium_rounded,
                  title: 'nearby_premium_title'.tr,
                  subtitle: 'nearby_premium_desc'.tr,
                ),
                child: PrimaryButton(
                  text: 'nearby_premium_cta'.tr,
                  onTap: () => sendAction(OpenNearbyPremium()),
                ),
              );
            }
            final err = state.error.value;
            if (err != null && state.people.isEmpty) {
              return _centered(
                AppEmptyState(
                  icon: Icons.wifi_off_rounded,
                  title: 'nearby_load_failed'.tr,
                  subtitle: err,
                ),
                child: SecondaryButton(
                  text: 'common_retry'.tr,
                  onTap: () => sendAction(RetryNearby()),
                ),
              );
            }
            if (state.people.isEmpty) {
              return RefreshIndicator(
                color: c.accentText,
                onRefresh: () async { await sendAction(RefreshNearby()); },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(20.dp, 40.dp, 20.dp, 24.dp),
                  children: [
                    AppEmptyState(
                      icon: Icons.near_me_outlined,
                      title: 'nearby_empty_title'.tr,
                      subtitle: 'nearby_empty_desc'.tr,
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              color: c.accentText,
              onRefresh: () async { await sendAction(RefreshNearby()); },
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(20.dp, 8.dp, 20.dp, 24.dp),
                itemCount: state.people.length,
                separatorBuilder: (_, _) => SizedBox(height: 10.dp),
                itemBuilder: (_, i) {
                  final p = state.people[i];
                  return NearbyUserItem(
                    person: p,
                    onTap: () => sendAction(OpenNearbyPerson(p)),
                    onMessage: () => sendAction(MessageNearbyPerson(p)),
                  );
                },
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _centered(Widget empty, {required Widget child}) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 28.dp),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            empty,
            SizedBox(height: 16.dp),
            child,
          ],
        ),
      ),
    );
  }
}
