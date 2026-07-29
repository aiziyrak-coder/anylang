import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../ui/theme/colors.dart';
import '../utils/app_snackbar.dart';
import '../utils/size_controller.dart';

/// Chat uchun video tanlash (kamera/galereya).
/// [maxSeconds] — oddiy video 120s, dumaloq video-note 60s.
Future<File?> pickChatVideo(
  BuildContext context, {
  required int maxSeconds,
  bool roundNote = false,
}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ChatVideoSourceSheet(
      maxSeconds: maxSeconds,
      roundNote: roundNote,
    ),
  );
  if (source == null) return null;

  final picked = await ImagePicker().pickVideo(
    source: source,
    maxDuration: Duration(seconds: maxSeconds),
  );
  if (picked == null) return null;

  final file = File(picked.path);
  final ok = await _ensureMaxDuration(file, maxSeconds: maxSeconds);
  if (!ok) {
    showAppError(
      roundNote ? 'chat_round_video_too_long'.tr : 'chat_video_too_long'.tr,
    );
    return null;
  }
  return file;
}

Future<bool> _ensureMaxDuration(File file, {required int maxSeconds}) async {
  VideoPlayerController? ctrl;
  try {
    ctrl = VideoPlayerController.file(file);
    await ctrl.initialize();
    final seconds = ctrl.value.duration.inMilliseconds / 1000.0;
    return seconds <= maxSeconds + 1.5;
  } catch (_) {
    return true;
  } finally {
    await ctrl?.dispose();
  }
}

class _ChatVideoSourceSheet extends StatelessWidget {
  final int maxSeconds;
  final bool roundNote;

  const _ChatVideoSourceSheet({
    required this.maxSeconds,
    required this.roundNote,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
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
              roundNote
                  ? 'chat_round_video_pick_title'.tr
                  : 'chat_video_pick_title'.tr,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6.dp),
            Text(
              roundNote
                  ? 'chat_round_video_hint'.tr
                  : 'chat_video_hint'.trParams({'n': '$maxSeconds'}),
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 13.sp),
            ),
            SizedBox(height: 12.dp),
            _option(
              context,
              c,
              Icons.videocam_outlined,
              'chat_video_pick_camera'.tr,
              ImageSource.camera,
            ),
            SizedBox(height: 8.dp),
            _option(
              context,
              c,
              Icons.video_library_outlined,
              'chat_video_pick_gallery'.tr,
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
        borderRadius: BorderRadius.circular(14.dp),
        child: Ink(
          padding: EdgeInsets.symmetric(horizontal: 14.dp, vertical: 14.dp),
          decoration: BoxDecoration(
            border: Border.all(color: c.surfaceBorder),
            borderRadius: BorderRadius.circular(14.dp),
          ),
          child: Row(
            children: [
              Icon(icon, color: c.accentText, size: 24.dp),
              SizedBox(width: 12.dp),
              Text(
                label,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
