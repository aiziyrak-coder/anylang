import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../data/core/mappers.dart';
import '../../../data/network/chat_repository.dart';
import '../../../data/network/nearby_repository.dart';
import '../../../data/network/profile_repository.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/auth_validators.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../chat/chat_payload.dart';
import '../chat/chat_screen.dart';
import '../subscription/subscription_screen.dart';
import '../user_profile/user_profile_payload.dart';
import '../user_profile/user_profile_screen.dart';
import 'nearby_action.dart';
import 'nearby_content.dart';
import 'nearby_person.dart';
import 'nearby_state.dart';

class NearbyScreen extends Screen<NearbyState, void> {
  NearbyScreen() : super(mobileContent: NearbyContent());

  @override
  void initState(void payload) {
    _load();
  }

  Future<Position?> _currentPosition() async {
    state.permissionDenied.value = false;
    state.locationServiceOff.value = false;
    state.gpsFailed.value = false;

    final status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) {
      state.permissionDenied.value = true;
      state.error.value = 'nearby_permission_title'.tr;
      return null;
    }
    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) {
      state.locationServiceOff.value = true;
      state.error.value = 'nearby_gps_off'.tr;
      showAppWarning('nearby_gps_off'.tr);
      return null;
    }
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
    } catch (_) {
      state.gpsFailed.value = true;
      state.error.value = 'nearby_gps_failed'.tr;
      showAppWarning('nearby_gps_failed'.tr);
      return null;
    }
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      state.refreshing.value = true;
    } else {
      state.loading.value = true;
    }
    state.error.value = null;

    final pos = await _currentPosition();
    if (pos == null) {
      state.loading.value = false;
      state.refreshing.value = false;
      return;
    }

    final locUpdate = await Get.find<NearbyRepository>().updateLocation(
      latitude: pos.latitude,
      longitude: pos.longitude,
      sharingEnabled: true,
    );
    if (locUpdate.errorOrNull != null) {
      state.error.value = AuthValidators.safeError(
        locUpdate.errorOrNull,
        fallbackKey: 'nearby_location_update_failed',
      );
      showAppError(locUpdate.errorOrNull);
      state.loading.value = false;
      state.refreshing.value = false;
      return;
    }

    final lang = state.languageFilter.value;
    final result = await Get.find<NearbyRepository>().listNearby(
      lat: pos.latitude,
      lng: pos.longitude,
      radiusM: state.radiusM.value,
      language: lang,
    );

    result.when(
      success: (data) {
        final map = asMap(data);
        if (map == null) {
          state.error.value = 'nearby_load_failed'.tr;
          state.loading.value = false;
          state.refreshing.value = false;
          return;
        }
        state.locked.value = map['locked'] == true;
        state.radiusM.value = (map['radius_m'] as num?)?.toInt() ?? 2000;
        final items = <NearbyPerson>[];
        for (final e in asList(map['items'])) {
          if (e is Map) {
            items.add(NearbyPerson.fromApi(Map<String, dynamic>.from(e)));
          }
        }
        state.people.assignAll(items);
        state.error.value = null;
      },
      failure: (err) {
        state.error.value = AuthValidators.safeError(
          err,
          fallbackKey: 'nearby_load_failed',
        );
        showAppError(err);
      },
    );

    state.loading.value = false;
    state.refreshing.value = false;
  }

  @override
  Future<void> actionHandler(NearbyState state, MyAction action) async {
    switch (action) {
      case BackFromNearby _:
        popBackNavigate();
      case RefreshNearby _:
      case RetryNearby _:
        await _load(refresh: true);
      case SelectNearbyLanguage a:
        state.languageFilter.value = a.languageCode;
        await _load(refresh: true);
      case OpenNearbyPremium _:
        await navigate(SubscriptionScreen());
        await _load(refresh: true);
      case ToggleNearbySharing a:
        final r = await Get.find<NearbyRepository>().setSharing(
          enabled: a.enabled,
        );
        r.when(
          success: (_) {
            state.sharingEnabled.value = a.enabled;
            showAppMessage(
              a.enabled ? 'nearby_sharing_on'.tr : 'nearby_sharing_off'.tr,
            );
          },
          failure: showAppError,
        );
      case OpenNearbyPerson a:
        final profile =
            await Get.find<ProfileRepository>().getPublicUser(a.person.id);
        final map = asMap(profile.dataOrNull);
        if (map == null) {
          showAppError(profile.errorOrNull ?? 'error'.tr);
          return;
        }
        await navigate(
          UserProfileScreen(),
          payload: UserProfilePayload.fromApi(map),
        );
      case MessageNearbyPerson a:
        final result =
            await Get.find<ChatRepository>().createChat(a.person.id);
        result.when(
          success: (data) {
            final map = asMap(data);
            final chatId = (map?['id'] as num?)?.toInt() ?? 0;
            if (chatId <= 0) {
              showAppError('chat_open_failed'.tr);
              return;
            }
            navigate(
              ChatScreen(),
              payload: ChatPayload(
                chatId: chatId,
                peerId: a.person.id,
                name: a.person.name,
                initial: a.person.initial,
                avatarGradient: avatarGradientFor(a.person.id),
                avatarUrl: a.person.avatarUrl,
              ),
            );
          },
          failure: showAppError,
        );
    }
  }
}
