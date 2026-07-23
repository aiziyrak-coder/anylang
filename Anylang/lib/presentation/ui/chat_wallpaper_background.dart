import 'package:flutter/material.dart';

import 'theme/colors.dart';

/// Chat doodle wallpaper — seamless tile (ImageRepeat), blur/seam yo'q.
class ChatWallpaperBackground extends StatelessWidget {
  final Widget child;

  const ChatWallpaperBackground({super.key, required this.child});

  static const lightAsset = 'assets/images/chat_bg_light.png';
  static const darkAsset = 'assets/images/chat_bg_dark.png';

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final asset = c.isDark ? darkAsset : lightAsset;
    final base = c.isDark ? const Color(0xFF000000) : const Color(0xFFF3EAF8);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    // 4x tile asset → scale ~2–2.5 so pattern crisp, not huge.
    final scale = (dpr >= 3) ? 2.2 : (dpr >= 2 ? 2.0 : 1.6);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: base,
        image: DecorationImage(
          image: AssetImage(asset),
          repeat: ImageRepeat.repeat,
          alignment: Alignment.topLeft,
          scale: scale,
          filterQuality: FilterQuality.high,
          opacity: c.isDark ? 0.92 : 0.78,
        ),
      ),
      child: SizedBox.expand(child: child),
    );
  }
}
