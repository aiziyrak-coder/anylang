import 'package:flutter/material.dart';

import 'theme/colors.dart';

/// Chat doodle wallpaper — light/dark asset, blur yo'q (tiniq).
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

    return ColoredBox(
      color: base,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            asset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
            isAntiAlias: true,
            gaplessPlayback: true,
          ),
          // Juda yengil overlay — o'qilish uchun, pattern ko'rinib turadi.
          ColoredBox(
            color: c.isDark
                ? const Color(0x1A000000)
                : const Color(0x0AFFFFFF),
          ),
          child,
        ],
      ),
    );
  }
}
