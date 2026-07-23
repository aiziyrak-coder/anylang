import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// To'liq ekranda rasm ko'rish — chat, mahsulot va boshqa joylarda bir xil.
Future<void> showFullScreenImage(
  BuildContext context, {
  required String url,
}) {
  HapticFeedback.selectionClick();
  return Navigator.of(context).push<void>(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.94),
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (ctx, animation, secondary) => FadeTransition(
        opacity: animation,
        child: FullScreenImageDialog(url: url),
      ),
    ),
  );
}

class FullScreenImageDialog extends StatelessWidget {
  final String url;

  const FullScreenImageDialog({super.key, required this.url});

  bool get _isNetwork =>
      url.startsWith('http://') || url.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
              child: Center(
                child: InteractiveViewer(
                  minScale: 0.85,
                  maxScale: 5,
                  child: _isNetwork
                      ? Image.network(
                          url,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white54,
                            size: 48,
                          ),
                        )
                      : Image.file(
                          File(url),
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white54,
                            size: 48,
                          ),
                        ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              left: 4,
              child: Material(
                color: Colors.black.withValues(alpha: 0.35),
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  color: Colors.white,
                  iconSize: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
