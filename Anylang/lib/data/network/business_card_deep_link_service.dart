import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/mappers.dart';
import '../local/session_store.dart';
import 'profile_repository.dart';
import '../../presentation/screens/user_profile/user_profile_payload.dart';
import '../../presentation/screens/user_profile/user_profile_screen.dart';
import '../../presentation/ui/business_card_links.dart';
import '../../presentation/utils/app_snackbar.dart';

/// `https://anylang.uz/b/{userId}` — Business Card QR deep link.
class BusinessCardDeepLinkService extends GetxService {
  StreamSubscription<Uri>? _sub;
  final _links = AppLinks();

  Future<BusinessCardDeepLinkService> init() async {
    try {
      final initial = await _links.getInitialLink();
      if (initial != null) {
        unawaited(_handle(initial));
      }
    } catch (_) {}
    _sub = _links.uriLinkStream.listen(_handle);
    return this;
  }

  Future<void> _handle(Uri uri) async {
    final id = BusinessCardLinks.userIdFromUri(uri);
    if (id == null || id <= 0) return;
    await openBusinessCard(id);
  }

  /// QR skaner / deep link → darhol kompaniya profili.
  Future<bool> openBusinessCard(int userId, {BuildContext? context}) async {
    if (userId <= 0) return false;
    if ((SessionStore.accessToken ?? '').isEmpty) return false;
    if (!Get.isRegistered<ProfileRepository>()) return false;

    final result = await Get.find<ProfileRepository>().getPublicUser(userId);
    var ok = false;
    result.when(
      success: (data) {
        final map = asMap(data);
        if (map == null) {
          showAppError('error'.tr);
          return;
        }
        ok = true;
        _pushProfile(UserProfilePayload.fromApi(map), context: context);
      },
      failure: showAppError,
    );
    return ok;
  }

  void _pushProfile(UserProfilePayload payload, {BuildContext? context}) {
    final ctx = context ?? Get.key.currentContext;
    if (ctx == null) return;
    Navigator.of(ctx).push(
      MaterialPageRoute(
        builder: (_) => (UserProfileScreen()..payload = payload).build(),
      ),
    );
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}
