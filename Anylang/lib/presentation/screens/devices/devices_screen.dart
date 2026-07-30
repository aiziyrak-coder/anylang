import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/core/mappers.dart';
import '../../../data/network/auth_repository.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/auth_validators.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import 'device_session.dart';
import 'devices_action.dart';
import 'devices_content.dart';
import 'devices_state.dart';

class DevicesScreen extends Screen<DevicesState, void> {
  DevicesScreen() : super(mobileContent: DevicesContent());

  @override
  void initState(void payload) {
    _load();
  }

  Future<void> _load() async {
    state.loading.value = true;
    state.error.value = null;
    final result = await Get.find<AuthRepository>().listSessions();
    if (result.errorOrNull != null) {
      state.error.value = AuthValidators.sessionError(
        result.errorOrNull,
        fallbackKey: 'devices_load_failed',
      );
      state.loading.value = false;
      return;
    }
    final map = asMap(result.dataOrNull);
    final currentMap = asMap(map?['current']);
    state.current.value =
        currentMap == null ? null : DeviceSession.fromApi(currentMap);
    final list = asList(map?['sessions'])
        .whereType<Map>()
        .map((e) => DeviceSession.fromApi(Map<String, dynamic>.from(e)))
        .where((s) => s.id.isNotEmpty)
        .toList();
    state.sessions.assignAll(list);
    state.canRevokeOthers.value = map?['can_revoke_others'] == true;
    state.loading.value = false;
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
  }) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('settings_cancel'.tr),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text(
              confirmLabel,
              style: TextStyle(
                color: Get.context != null
                    ? Theme.of(Get.context!).colorScheme.error
                    : null,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      barrierDismissible: true,
    );
    return ok == true;
  }

  @override
  Future<void> actionHandler(DevicesState state, MyAction action) async {
    switch (action) {
      case Back _:
        popBackNavigate();
      case RefreshDevices _:
        await _load();
      case RevokeDeviceSession a:
        if (!a.session.canRevoke || state.busy.value) return;
        final confirmed = await _confirm(
          title: 'devices_confirm_revoke_title'.tr,
          body: 'devices_confirm_revoke_body'.trParams({
            'device': a.session.displayName,
          }),
          confirmLabel: 'devices_revoke'.tr,
        );
        if (!confirmed) return;
        state.busy.value = true;
        state.revokingId.value = a.session.id;
        try {
          final result =
              await Get.find<AuthRepository>().revokeSession(a.session.id);
          if (result.errorOrNull != null) {
            showAppError(AuthValidators.sessionError(result.errorOrNull));
            return;
          }
          showAppMessage('devices_revoked'.tr);
          await _load();
        } finally {
          state.busy.value = false;
          state.revokingId.value = null;
        }
      case RevokeOtherDeviceSessions _:
        if (!state.canRevokeOthers.value || state.busy.value) return;
        final confirmed = await _confirm(
          title: 'devices_confirm_others_title'.tr,
          body: 'devices_confirm_others_body'.tr,
          confirmLabel: 'devices_terminate_others'.tr,
        );
        if (!confirmed) return;
        state.busy.value = true;
        try {
          final result = await Get.find<AuthRepository>().revokeOtherSessions();
          if (result.errorOrNull != null) {
            showAppError(AuthValidators.sessionError(result.errorOrNull));
            return;
          }
          final map = asMap(result.dataOrNull);
          final revoked = map?['revoked_count'];
          final skipped = map?['skipped_protected'];
          if (skipped is num && skipped > 0) {
            showAppMessage(
              'devices_others_revoked_partial'.trParams({
                'n': '${revoked is num ? revoked.toInt() : 0}',
                'skip': '${skipped.toInt()}',
              }),
            );
          } else {
            showAppMessage('devices_others_revoked'.tr);
          }
          await _load();
        } finally {
          state.busy.value = false;
        }
    }
  }
}
