import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../ui/theme/colors.dart';
import '../utils/app_snackbar.dart';
import '../utils/size_controller.dart';

/// Mahsulotning qisqa videosini to‘liq ekranda ko‘rsatadi.
/// YouTube / tashqi sahifalar — tashqi brauzerda ochiladi.
Future<void> showProductVideoDialog(
  BuildContext context, {
  required String url,
}) async {
  final raw = url.trim();
  if (raw.isEmpty) return;

  if (_isExternalPage(raw)) {
    final uri = Uri.tryParse(raw);
    if (uri == null) {
      showAppError('product_video_open_failed'.tr);
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) showAppError('product_video_open_failed'.tr);
    return;
  }

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.92),
    builder: (_) => _ProductVideoDialog(url: raw),
  );
}

bool _isExternalPage(String url) {
  final lower = url.toLowerCase();
  return lower.contains('youtube.com') ||
      lower.contains('youtu.be') ||
      lower.contains('vimeo.com') ||
      lower.contains('tiktok.com');
}

class _ProductVideoDialog extends StatefulWidget {
  final String url;

  const _ProductVideoDialog({required this.url});

  @override
  State<_ProductVideoDialog> createState() => _ProductVideoDialogState();
}

class _ProductVideoDialogState extends State<_ProductVideoDialog> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;
  static const _maxPlay = Duration(seconds: 15);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = ctrl;
    try {
      await ctrl.initialize();
      if (!mounted) return;
      ctrl.setLooping(false);
      await ctrl.play();
      ctrl.addListener(_onTick);
      setState(() => _ready = true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  void _onTick() {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (ctrl.value.position >= _maxPlay) {
      ctrl.pause();
      ctrl.seekTo(_maxPlay);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final ctrl = _controller;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 16.dp, vertical: 24.dp),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close_rounded, color: Colors.white, size: 28.dp),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(16.dp),
            child: AspectRatio(
              aspectRatio: ctrl != null && _ready && ctrl.value.aspectRatio > 0
                  ? ctrl.value.aspectRatio
                  : 16 / 9,
              child: ColoredBox(
                color: Colors.black,
                child: _failed
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.dp),
                          child: Text(
                            'product_video_open_failed'.tr,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 14.sp),
                          ),
                        ),
                      )
                    : !_ready
                        ? Center(
                            child: CircularProgressIndicator(
                              color: c.accent,
                              strokeWidth: 2.dp,
                            ),
                          )
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              VideoPlayer(ctrl!),
                              Positioned(
                                left: 12.dp,
                                bottom: 12.dp,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10.dp,
                                    vertical: 5.dp,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(99.dp),
                                  ),
                                  child: Text(
                                    'product_video_15s_badge'.tr,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              Center(
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      if (ctrl.value.isPlaying) {
                                        ctrl.pause();
                                      } else {
                                        if (ctrl.value.position >= _maxPlay) {
                                          ctrl.seekTo(Duration.zero);
                                        }
                                        ctrl.play();
                                      }
                                      setState(() {});
                                    },
                                    customBorder: const CircleBorder(),
                                    child: Ink(
                                      width: 56.dp,
                                      height: 56.dp,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.35),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        ctrl.value.isPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 34.dp,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
              ),
            ),
          ),
          SizedBox(height: 10.dp),
          Text(
            'product_video_15s_hint'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 12.sp,
            ),
          ),
        ],
      ),
    );
  }
}
