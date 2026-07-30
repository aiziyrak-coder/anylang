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
      state.error.value = AuthValidators.safeError(
        result.errorOrNull,
        fallbackKey: 'error_generic',
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

  @override
  Future<void> actionHandler(DevicesState state, MyAction action) async {
    switch (action) {
      case Back _:
        popBackNavigate();
      case RefreshDevices _:
        await _load();
      case RevokeDeviceSession a:
        if (!a.session.canRevoke || state.busy.value) return;
        state.busy.value = true;
        try {
          final result =
              await Get.find<AuthRepository>().revokeSession(a.session.id);
          if (result.errorOrNull != null) {
            showAppError(result.errorOrNull);
            return;
          }
          showAppMessage('devices_revoked'.tr);
          await _load();
        } finally {
          state.busy.value = false;
        }
      case RevokeOtherDeviceSessions _:
        if (!state.canRevokeOthers.value || state.busy.value) return;
        state.busy.value = true;
        try {
          final result = await Get.find<AuthRepository>().revokeOtherSessions();
          if (result.errorOrNull != null) {
            showAppError(result.errorOrNull);
            return;
          }
          showAppMessage('devices_others_revoked'.tr);
          await _load();
        } finally {
          state.busy.value = false;
        }
    }
  }
}
