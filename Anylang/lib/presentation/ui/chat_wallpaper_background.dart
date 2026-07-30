import 'package:flutter/material.dart';

import 'theme/colors.dart';

/// Chat orqa foni — premium bokeh wallpaper + yengil veil (o‘qilishi uchun).
class ChatWallpaperBackground extends StatelessWidget {
  final Widget child;

  const ChatWallpaperBackground({super.key, required this.child});

  static const _asset = 'assets/images/chat_wallpaper_bokeh.png';

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(
          child: ColoredBox(color: Color(0xFF0A0C10)),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Image.asset(
              _asset,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, error, stackTrace) =>
                  ColoredBox(color: c.background),
            ),
          ),
        ),
        // Depth + readability — wallpaper ko‘rinsin, matn o‘qilsin.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: c.isDark
                      ? const [
                          Color(0x66060A10),
                          Color(0x33060A10),
                          Color(0x77060A10),
                        ]
                      : const [
                          Color(0x55F5F6F8),
                          Color(0x33F5F6F8),
                          Color(0x66F5F6F8),
                        ],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
