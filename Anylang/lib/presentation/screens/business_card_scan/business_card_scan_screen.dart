import 'package:get/get.dart';

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
  Future<void> actionHandler(BusinessCardScanState state, MyAction action) async {
    switch (action) {
      case CloseBusinessCardScan _:
        popBackNavigate();
      case BusinessCardScanned a:
        if (state.handled.value) return;
        final id = BusinessCardLinks.userIdFromText(a.raw);
        if (id == null || id <= 0) {
          state.error.value = 'business_card_invalid_qr'.tr;
          return;
        }
        state.handled.value = true;
        state.error.value = null;
        // Avval skaner yopiladi, keyin profil ochiladi (stack chalkashmasin).
        popBackNavigate();
        await Future<void>.delayed(Duration.zero);
        await Get.find<BusinessCardDeepLinkService>().openBusinessCard(id);
      default:
        break;
    }
  }
}
