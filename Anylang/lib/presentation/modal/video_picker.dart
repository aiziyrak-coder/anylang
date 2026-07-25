import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../ui/theme/colors.dart';
import '../utils/app_snackbar.dart';
import '../utils/size_controller.dart';

/// Mahsulot uchun qisqa video tanlash (kamera/galereya).
/// Maksimal davomiylik: 15 soniya.
Future<File?> pickProductVideo(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _VideoSourceSheet(),
  );
  if (source == null) return null;

  final picked = await ImagePicker().pickVideo(
    source: source,
    maxDuration: const Duration(seconds: 15),
  );
  if (picked == null) return null;

  final file = File(picked.path);
  final ok = await _ensureMaxDuration(file);
  if (!ok) {
    showAppError('product_video_too_long'.tr);
    return null;
  }
  return file;
}

Future<bool> _ensureMaxDuration(File file) async {
  VideoPlayerController? ctrl;
  try {
    ctrl = VideoPlayerController.file(file);
    await ctrl.initialize();
    final seconds = ctrl.value.duration.inMilliseconds / 1000.0;
    // Kamera maxDuration ba'zan 1–2s chegara oshishi mumkin.
    return seconds <= 16.5;
  } catch (_) {
    // Duration o‘qib bo‘lmasa — yuklashga ruxsat (server MIME tekshiradi).
    return true;
  } finally {
    await ctrl?.dispose();
  }
}

class _VideoSourceSheet extends StatelessWidget {
  const _VideoSourceSheet();

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Container(
      decoration: BoxDecoration(
        color: c.isDark ? const Color(0xFF0C2136) : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.dp)),
      ),
      padding: EdgeInsets.fromLTRB(20.dp, 12.dp, 20.dp, 24.dp),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44.dp,
              height: 5.dp,
              decoration: BoxDecoration(
                color: c.outline,
                borderRadius: BorderRadius.circular(5.dp),
              ),
            ),
            SizedBox(height: 16.dp),
            Text(
              'product_video_pick_title'.tr,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6.dp),
            Text(
              'product_video_15s_hint'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 13.sp),
            ),
            SizedBox(height: 12.dp),
            _option(
              context,
              c,
              Icons.videocam_outlined,
              'product_video_pick_camera'.tr,
              ImageSource.camera,
            ),
            _option(
              context,
              c,
              Icons.video_library_outlined,
              'product_video_pick_gallery'.tr,
              ImageSource.gallery,
            ),
          ],
        ),
      ),
    );
  }

  Widget _option(
    BuildContext context,
    AppColors c,
    IconData icon,
    String label,
    ImageSource source,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pop(context, source),
        borderRadius: BorderRadius.circular(12.dp),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 14.dp, horizontal: 8.dp),
          child: Row(
            children: [
              Icon(icon, color: c.textSecondary, size: 22.dp),
              SizedBox(width: 14.dp),
              Text(
                label,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
