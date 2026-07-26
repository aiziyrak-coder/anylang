import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../ui/buttons/my_icon_button.dart';
import '../../ui/theme/colors.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import 'business_card_scan_action.dart';
import 'business_card_scan_state.dart';

class BusinessCardScanContent extends ScreenContent<BusinessCardScanState> {
  BusinessCardScanContent() : super(color: Colors.black);

  @override
  Widget build(
    BuildContext context,
    BusinessCardScanState state,
    FutureOr<void> Function(MyAction action) sendAction,
  ) {
    final c = context.appColors;

    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(8.dp, 4.dp, 12.dp, 0),
            child: Row(
              children: [
                MyIconButton(
                  onClick: () => sendAction(CloseBusinessCardScan()),
                  icon: Icons.arrow_back_ios_new,
                  iconColor: Colors.white,
                  iconSize: 20.dp,
                  backgroundColor: Colors.transparent,
                  borderRadius: 12.dp,
                  padding: EdgeInsets.all(6.dp),
                ),
                SizedBox(width: 6.dp),
                Expanded(
                  child: Text(
                    'business_card_scan_title'.tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20.dp, 8.dp, 20.dp, 12.dp),
          child: Text(
            'business_card_scan_hint'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13.sp,
              height: 1.35,
            ),
          ),
        ),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                onDetect: (capture) {
                  if (state.handled.value) return;
                  for (final b in capture.barcodes) {
                    final raw = b.rawValue;
                    if (raw == null || raw.isEmpty) continue;
                    sendAction(BusinessCardScanned(raw));
                    break;
                  }
                },
              ),
              IgnorePointer(
                child: Center(
                  child: Container(
                    width: 240.dp,
                    height: 240.dp,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20.dp),
                      border: Border.all(color: c.accent, width: 2.5),
                    ),
                  ),
                ),
              ),
              Obx(() {
                final err = state.error.value;
                if (err == null || err.isEmpty) return const SizedBox.shrink();
                return Positioned(
                  left: 20.dp,
                  right: 20.dp,
                  bottom: 28.dp,
                  child: Container(
                    padding: EdgeInsets.all(12.dp),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12.dp),
                    ),
                    child: Text(
                      err,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 13.sp),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}
