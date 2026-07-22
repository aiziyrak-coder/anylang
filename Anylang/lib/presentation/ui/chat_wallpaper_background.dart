import 'dart:ui';

import 'package:flutter/material.dart';

import 'theme/colors.dart';

/// Chat ekrani Telegram-uslubidagi doodle foni — light/dark alohida asset.
/// Fon biroz blur qilinadi (xabarlar o‘qilishi osonroq).
class ChatWallpaperBackground extends StatelessWidget {
  final Widget child;

  const ChatWallpaperBackground({super.key, required this.child});

  static const lightAsset = 'assets/images/chat_bg_light.png';
  static const darkAsset = 'assets/images/chat_bg_dark.png';

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final asset = c.isDark ? darkAsset : lightAsset;
    final base = c.isDark ? const Color(0xFF07111F) : const Color(0xFFF3F5F8);

    return ColoredBox(
      color: base,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 1.8, sigmaY: 1.8),
            child: Image.asset(
              asset,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              filterQuality: FilterQuality.medium,
            ),
          ),
          // Yengil overlay — kontrast + yumshoqroq ko‘rinish.
          ColoredBox(
            color: c.isDark
                ? const Color(0x33000000)
                : const Color(0x14FFFFFF),
          ),
          child,
        ],
      ),
    );
  }
}
