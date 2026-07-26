import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../data/network/business_card_deep_link_service.dart';
import '../../ui/business_card_links.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import 'business_card_scan_action.dart';
import 'business_card_scan_content.dart';
import 'business_card_scan_state.dart';

class BusinessCardScanScreen extends Screen<BusinessCardScanState, void> {
  BusinessCardScanScreen() : super(mobileContent: BusinessCardScanContent());

  @override
  void initState(void payload) {
    state.handled.value = false;
    state.error.value = null;
    Future.microtask(_ensureCamera);
  }

  Future<void> _ensureCamera() async {
    final status = await Permission.camera.status;
    if (status.isGranted) return;
    final req = await Permission.camera.request();
    if (!req.isGranted && !req.isLimited) {
      state.error.value = 'business_card_permission_denied'.tr;
    }
  }

  @override
  Future<void> actionHandler(BusinessCardScanState state, MyAction action) async {
    switch (action) {
      case CloseBusinessCardScan _:
        popBackNavigate();
      case BusinessCardClearError _:
        state.error.value = null;
        state.handled.value = false;
      case BusinessCardScanned a:
        if (state.handled.value) return;
        final id = BusinessCardLinks.userIdFromText(a.raw);
        if (id == null || id <= 0) {
          state.error.value = 'business_card_invalid_qr'.tr;
          state.handled.value = false;
          return;
        }
        state.handled.value = true;
        state.error.value = null;
        popBackNavigate();
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await Get.find<BusinessCardDeepLinkService>().openBusinessCard(id);
        });
      default:
        break;
    }
  }
}
