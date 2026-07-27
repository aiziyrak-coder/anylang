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

class FullScreenImageDialog extends StatefulWidget {
  final String url;

  const FullScreenImageDialog({super.key, required this.url});

  @override
  State<FullScreenImageDialog> createState() => _FullScreenImageDialogState();
}

class _FullScreenImageDialogState extends State<FullScreenImageDialog> {
  final _transform = TransformationController();
  TapDownDetails? _doubleTapDetails;

  bool get _isNetwork =>
      widget.url.startsWith('http://') || widget.url.startsWith('https://');

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    final pos = _doubleTapDetails?.localPosition;
    if (pos == null) return;
    final current = _transform.value.getMaxScaleOnAxis();
    if (current > 1.05) {
      _transform.value = Matrix4.identity();
      return;
    }
    const scale = 2.5;
    final x = -pos.dx * (scale - 1);
    final y = -pos.dy * (scale - 1);
    _transform.value = Matrix4.identity()
      ..translateByDouble(x, y, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  Widget _image() {
    if (_isNetwork) {
      return Image.network(
        widget.url,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => const Icon(
          Icons.broken_image_outlined,
          color: Colors.white54,
          size: 48,
        ),
      );
    }
    return Image.file(
      File(widget.url),
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, _, _) => const Icon(
        Icons.broken_image_outlined,
        color: Colors.white54,
        size: 48,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // To‘liq viewport — zoom rasm qutisi ichida emas, butun ekranda.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_transform.value.getMaxScaleOnAxis() <= 1.05) {
                Navigator.of(context).maybePop();
              } else {
                _transform.value = Matrix4.identity();
              }
            },
            onDoubleTapDown: (d) => _doubleTapDetails = d,
            onDoubleTap: _onDoubleTap,
            child: InteractiveViewer(
              transformationController: _transform,
              minScale: 1,
              maxScale: 5,
              clipBehavior: Clip.none,
              panEnabled: true,
              scaleEnabled: true,
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: _image(),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Material(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: IconButton(
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    color: Colors.white,
                    iconSize: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
