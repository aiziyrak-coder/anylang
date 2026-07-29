import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../ui/theme/colors.dart';
import '../../utils/size_controller.dart';

/// Dumaloq video-note yozish paytidagi markaziy kamera oynasi (Telegram uslubi).
class VideoNoteRecordOverlay extends StatelessWidget {
  final CameraController? controller;
  final String elapsed;
  final VoidCallback? onFlipCamera;

  const VideoNoteRecordOverlay({
    super.key,
    required this.controller,
    required this.elapsed,
    this.onFlipCamera,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final ctrl = controller;
    final ready = ctrl != null && ctrl.value.isInitialized;
    final size = 260.dp;

    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.72),
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ClipOval(
                    child: SizedBox(
                      width: size,
                      height: size,
                      child: ready
                          ? FittedBox(
                              fit: BoxFit.cover,
                              clipBehavior: Clip.hardEdge,
                              child: SizedBox(
                                width: ctrl.value.previewSize?.height ?? size,
                                height: ctrl.value.previewSize?.width ?? size,
                                child: CameraPreview(ctrl),
                              ),
                            )
                          : ColoredBox(
                              color: c.surface,
                              child: Center(
                                child: SizedBox(
                                  width: 28.dp,
                                  height: 28.dp,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: c.accent,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                  IgnorePointer(
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: c.accent.withValues(alpha: 0.85),
                          width: 3.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.dp),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8.dp,
                  height: 8.dp,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF3B30),
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 8.dp),
                Text(
                  elapsed,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            if (onFlipCamera != null) ...[
              SizedBox(height: 16.dp),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onFlipCamera,
                  borderRadius: BorderRadius.circular(22.dp),
                  child: Padding(
                    padding: EdgeInsets.all(10.dp),
                    child: Icon(
                      Icons.cameraswitch_rounded,
                      color: Colors.white,
                      size: 26.dp,
                    ),
                  ),
                ),
              ),
            ],
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}
