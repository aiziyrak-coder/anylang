import 'package:flutter/material.dart';

import 'theme/colors.dart';

/// Chat ekrani Telegram-uslubidagi doodle foni — light/dark alohida asset.
class ChatWallpaperBackground extends StatelessWidget {
  final Widget child;

  const ChatWallpaperBackground({super.key, required this.child});

  static const lightAsset = 'assets/images/chat_bg_light.png';
  static const darkAsset = 'assets/images/chat_bg_dark.png';

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.isDark ? const Color(0xFF07111F) : const Color(0xFFF3F5F8),
        image: DecorationImage(
          image: AssetImage(c.isDark ? darkAsset : lightAsset),
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          filterQuality: FilterQuality.medium,
        ),
      ),
      child: SizedBox.expand(child: child),
    );
  }
}
