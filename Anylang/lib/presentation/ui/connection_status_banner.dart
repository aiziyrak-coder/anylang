import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/network/connection_status_service.dart';
import '../utils/size_controller.dart';
import 'theme/colors.dart';

/// Telegram uslubidagi tarmoq holati lentasi:
/// - Waiting for network
/// - Connecting…
class ConnectionStatusBanner extends StatelessWidget {
  const ConnectionStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<ConnectionStatusService>()) {
      return const SizedBox.shrink();
    }
    final c = context.appColors;
    return Obx(() {
      final phase = Get.find<ConnectionStatusService>().phase.value;
      if (phase == NetworkBannerPhase.none) {
        return const SizedBox.shrink();
      }

      final waiting = phase == NetworkBannerPhase.waitingForNetwork;
      final bg = waiting
          ? (c.isDark ? const Color(0xFF5C4A12) : const Color(0xFFFFF3CD))
          : (c.isDark ? const Color(0xFF1A3A52) : const Color(0xFFE8F4FC));
      final fg = waiting
          ? (c.isDark ? const Color(0xFFFFE08A) : const Color(0xFF6B5200))
          : (c.isDark ? const Color(0xFF9ED0FF) : const Color(0xFF0B5CAB));
      final icon = waiting
          ? Icons.cloud_off_rounded
          : Icons.sync_rounded;
      final text = waiting
          ? 'connection_waiting_network'.tr
          : 'connection_connecting'.tr;

      return Material(
        color: bg,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.dp, vertical: 8.dp),
          child: Row(
            children: [
              Icon(icon, size: 18.dp, color: fg),
              SizedBox(width: 8.dp),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: fg,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
              if (!waiting)
                SizedBox(
                  width: 14.dp,
                  height: 14.dp,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: fg,
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}
