import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'theme/colors.dart';

/// Chat doodle wallpaper — **SVG vektor** tile (PNG emas).
/// Har bir tile `flutter_svg` orqali chiziladi → DPR qancha bo'lsa ham tiniq.
class ChatWallpaperBackground extends StatelessWidget {
  final Widget child;

  const ChatWallpaperBackground({super.key, required this.child});

  static const lightAsset = 'assets/images/chat_bg_light.svg';
  static const darkAsset = 'assets/images/chat_bg_dark.svg';

  /// Tile logical size (viewBox 240×400 ga proporsional).
  static const tileWidth = 168.0;
  static const tileHeight = 280.0;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final asset = c.isDark ? darkAsset : lightAsset;
    final base = c.isDark ? const Color(0xFF000000) : const Color(0xFFE5E5F9);
    final opacity = c.isDark ? 0.62 : 0.78;

    return ColoredBox(
      color: base,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: opacity,
                child: _TiledSvgWallpaper(
                  asset: asset,
                  tileWidth: tileWidth,
                  tileHeight: tileHeight,
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _TiledSvgWallpaper extends StatefulWidget {
  final String asset;
  final double tileWidth;
  final double tileHeight;

  const _TiledSvgWallpaper({
    required this.asset,
    required this.tileWidth,
    required this.tileHeight,
  });

  @override
  State<_TiledSvgWallpaper> createState() => _TiledSvgWallpaperState();
}

class _TiledSvgWallpaperState extends State<_TiledSvgWallpaper> {
  PictureInfo? _picture;
  Object? _error;
  String? _loadedAsset;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_ensureLoaded());
  }

  @override
  void didUpdateWidget(covariant _TiledSvgWallpaper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset != widget.asset) {
      unawaited(_ensureLoaded(force: true));
    }
  }

  Future<void> _ensureLoaded({bool force = false}) async {
    if (!force && _loadedAsset == widget.asset && _picture != null) return;
    final asset = widget.asset;
    try {
      final info = await vg.loadPicture(SvgAssetLoader(asset), null);
      if (!mounted || asset != widget.asset) {
        info.picture.dispose();
        return;
      }
      _picture?.picture.dispose();
      setState(() {
        _picture = info;
        _loadedAsset = asset;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _picture?.picture.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pic = _picture;
    if (pic == null) {
      return const SizedBox.expand();
    }
    if (_error != null) {
      return const SizedBox.expand();
    }
    return CustomPaint(
      painter: _SvgTilePainter(
        picture: pic.picture,
        srcSize: pic.size,
        tileWidth: widget.tileWidth,
        tileHeight: widget.tileHeight,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _SvgTilePainter extends CustomPainter {
  final ui.Picture picture;
  final Size srcSize;
  final double tileWidth;
  final double tileHeight;

  _SvgTilePainter({
    required this.picture,
    required this.srcSize,
    required this.tileWidth,
    required this.tileHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (srcSize.width <= 0 || srcSize.height <= 0) return;
    final sx = tileWidth / srcSize.width;
    final sy = tileHeight / srcSize.height;
    final cols = (size.width / tileWidth).ceil() + 1;
    final rows = (size.height / tileHeight).ceil() + 1;

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        canvas.save();
        canvas.translate(col * tileWidth, row * tileHeight);
        canvas.scale(sx, sy);
        canvas.drawPicture(picture);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SvgTilePainter oldDelegate) {
    return oldDelegate.picture != picture ||
        oldDelegate.tileWidth != tileWidth ||
        oldDelegate.tileHeight != tileHeight ||
        oldDelegate.srcSize != srcSize;
  }
}
