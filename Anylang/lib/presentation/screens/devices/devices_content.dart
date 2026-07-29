import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../ui/app_empty_state.dart';
import '../../ui/app_loading.dart';
import '../../ui/app_top_bar.dart';
import '../../ui/gradient_background.dart';
import '../../ui/theme/colors.dart';
import '../../utils/formatters/time_formatter.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import 'device_session.dart';
import 'devices_action.dart';
import 'devices_state.dart';

class DevicesContent extends ScreenContent<DevicesState> {
  @override
  Widget build(
    BuildContext context,
    DevicesState state,
    FutureOr<void> Function(MyAction action) sendAction,
  ) {
    final c = context.appColors;
    return GradientBackground(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.dp, 4.dp, 16.dp, 0),
              child: AppTopBar(
                title: 'devices_title'.tr,
                onBack: () => sendAction(Back()),
              ),
            ),
            Expanded(
              child: Obx(() {
                if (state.loading.value &&
                    state.current.value == null &&
                    state.sessions.isEmpty) {
                  return const AppLoading();
                }
                final err = state.error.value;
                if (err != null &&
                    state.current.value == null &&
                    state.sessions.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.dp),
                      child: AppEmptyState(
                        icon: Icons.devices_other_outlined,
                        title: 'devices_load_failed'.tr,
                        subtitle: err,
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  color: c.accentText,
                  onRefresh: () async {
                    await sendAction(RefreshDevices());
                  },
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(16.dp, 12.dp, 16.dp, 28.dp),
                    children: [
                      Text(
                        'devices_intro'.tr,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 13.sp,
                          height: 1.35,
                        ),
                      ),
                      SizedBox(height: 18.dp),
                      _sectionLabel(c, 'devices_this_device'.tr),
                      SizedBox(height: 8.dp),
                      _card(
                        c,
                        children: [
                          if (state.current.value != null)
                            _sessionTile(c, state.current.value!, sendAction)
                          else
                            Padding(
                              padding: EdgeInsets.all(16.dp),
                              child: Text(
                                'devices_current_unknown'.tr,
                                style: TextStyle(
                                  color: c.textSecondary,
                                  fontSize: 13.sp,
                                ),
                              ),
                            ),
                          if (state.sessions.isNotEmpty) ...[
                            Divider(
                              height: 1.dp,
                              thickness: 0.5,
                              color: c.outline,
                            ),
                            _terminateOthersRow(c, state, sendAction),
                          ],
                        ],
                      ),
                      if (state.sessions.isNotEmpty) ...[
                        SizedBox(height: 8.dp),
                        Text(
                          'devices_terminate_others_hint'.tr,
                          style: TextStyle(
                            color: c.textFaint,
                            fontSize: 12.sp,
                            height: 1.3,
                          ),
                        ),
                        SizedBox(height: 20.dp),
                        _sectionLabel(c, 'devices_active_sessions'.tr),
                        SizedBox(height: 8.dp),
                        _card(
                          c,
                          children: [
                            for (var i = 0; i < state.sessions.length; i++) ...[
                              if (i > 0)
                                Divider(
                                  height: 1.dp,
                                  thickness: 0.5,
                                  color: c.outline,
                                ),
                              _sessionTile(
                                c,
                                state.sessions[i],
                                sendAction,
                                showRevoke: true,
                              ),
                            ],
                          ],
                        ),
                      ],
                      SizedBox(height: 18.dp),
                      Text(
                        'devices_protect_hint'.tr,
                        style: TextStyle(
                          color: c.textFaint,
                          fontSize: 12.sp,
                          height: 1.35,
                        ),
                      ),
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

  Widget _sectionLabel(AppColors c, String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: c.textFaint,
        fontSize: 12.sp,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
    );
  }

  Widget _card(AppColors c, {required List<Widget> children}) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16.dp),
        border: Border.all(color: c.surfaceBorder, width: 0.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _terminateOthersRow(
    AppColors c,
    DevicesState state,
    void Function(MyAction) sendAction,
  ) {
    final enabled = state.canRevokeOthers.value && !state.busy.value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled
            ? () => sendAction(RevokeOtherDeviceSessions())
            : null,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.dp, vertical: 14.dp),
          child: Row(
            children: [
              Container(
                width: 40.dp,
                height: 40.dp,
                decoration: BoxDecoration(
                  color: c.dangerSoft.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12.dp),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.front_hand_outlined,
                  color: c.danger,
                  size: 20.dp,
                ),
              ),
              SizedBox(width: 12.dp),
              Expanded(
                child: Text(
                  'devices_terminate_others'.tr,
                  style: TextStyle(
                    color: enabled ? c.danger : c.textFaint,
                    fontSize: 14.sp,
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

  Widget _sessionTile(
    AppColors c,
    DeviceSession s,
    void Function(MyAction) sendAction, {
    bool showRevoke = false,
  }) {
    final subtitle = [
      if ((s.platform ?? '').trim().isNotEmpty) s.platform!.trim(),
      if ((s.appVersion ?? '').trim().isNotEmpty) 'v${s.appVersion}',
    ].join(' · ');
    final activity = s.isOnline
        ? 'devices_online'.tr
        : (s.lastActiveAt == null
            ? ''
            : formatLastActivity(online: false, lastSeenAt: s.lastActiveAt));
    return Padding(
      padding: EdgeInsets.fromLTRB(14.dp, 12.dp, 8.dp, 12.dp),
      child: Row(
        children: [
          Container(
            width: 40.dp,
            height: 40.dp,
            decoration: BoxDecoration(
              color: c.accentSoft,
              borderRadius: BorderRadius.circular(12.dp),
            ),
            alignment: Alignment.center,
            child: Icon(
              s.isPhone
                  ? Icons.smartphone_rounded
                  : Icons.desktop_windows_outlined,
              color: c.accentText,
              size: 22.dp,
            ),
          ),
          SizedBox(width: 12.dp),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.deviceName,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  SizedBox(height: 2.dp),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
                if (activity.isNotEmpty) ...[
                  SizedBox(height: 2.dp),
                  Text(
                    activity,
                    style: TextStyle(
                      color: s.isOnline ? c.accentText : c.textFaint,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (showRevoke && s.canRevoke)
            IconButton(
              tooltip: 'devices_revoke'.tr,
              onPressed: () => sendAction(RevokeDeviceSession(s)),
              icon: Icon(Icons.close_rounded, color: c.danger, size: 20.dp),
            ),
        ],
      ),
    );
  }
}
