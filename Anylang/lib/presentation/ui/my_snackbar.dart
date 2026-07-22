import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';

enum SnackBarStatus {
  success,
  error,
  warning,
}

/// Overlay snackbar (Lottie) — POST/PUT/PATCH/DELETE va qo'lda chaqiriqlar uchun.
class MySnackBar {
  static OverlayEntry? _current;
  static String? _lastMessage;
  static DateTime? _lastAt;

  static void show({
    BuildContext? context,
    required SnackBarStatus status,
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    final text = message.trim();
    if (text.isEmpty) return;

    // Bir xil xabar spamini oldini olish (NetworkClient + screen ikkalasi).
    final now = DateTime.now();
    if (_lastMessage == text &&
        _lastAt != null &&
        now.difference(_lastAt!) < const Duration(milliseconds: 800)) {
      return;
    }
    _lastMessage = text;
    _lastAt = now;

    final ctx = context ?? Get.overlayContext ?? Get.context;
    if (ctx == null) {
      debugPrint('MySnackBar: no context — $title: $text');
      return;
    }

    try {
      _current?.remove();
    } catch (_) {}

    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (_) {
        return _AnimatedSnackBar(
          title: title,
          message: text,
          status: status,
          duration: duration,
          onDismissed: () {
            if (_current == overlayEntry) {
              _current = null;
            }
            try {
              overlayEntry.remove();
            } catch (_) {}
          },
        );
      },
    );

    try {
      _current = overlayEntry;
      Overlay.of(ctx, rootOverlay: true).insert(overlayEntry);
      return;
    } catch (e) {
      debugPrint('MySnackBar overlay failed: $e');
      _current = null;
    }

    // Fallback — Overlay bo‘lmasa ham xabar ko‘rinsin.
    try {
      final color = switch (status) {
        SnackBarStatus.success => const Color(0xFF027A48),
        SnackBarStatus.error => const Color(0xFFB42318),
        SnackBarStatus.warning => const Color(0xFFB54708),
      };
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text('$title\n$text'),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          duration: duration,
        ),
      );
    } catch (e) {
      debugPrint('MySnackBar scaffold fallback failed: $e — $title: $text');
    }
  }
}

class _AnimatedSnackBar extends StatefulWidget {
  final String title;
  final String message;
  final SnackBarStatus status;
  final Duration duration;
  final VoidCallback onDismissed;

  const _AnimatedSnackBar({
    required this.title,
    required this.status,
    required this.message,
    required this.duration,
    required this.onDismissed,
  });

  @override
  State<_AnimatedSnackBar> createState() => _AnimatedSnackBarState();
}

class _AnimatedSnackBarState extends State<_AnimatedSnackBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;

  Color backgroundColor = Colors.green;
  String animation = 'assets/animations/success_snack.json';
  bool _isClosing = false;

  @override
  void initState() {
    switch (widget.status) {
      case SnackBarStatus.success:
        backgroundColor = const Color(0xFF027A48);
        animation = 'assets/animations/success_snack.json';
      case SnackBarStatus.error:
        backgroundColor = const Color(0xFFB42318);
        animation = 'assets/animations/snack_error.json';
      case SnackBarStatus.warning:
        backgroundColor = const Color(0xFFB54708);
        animation = 'assets/animations/anim_warning.json';
    }

    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      reverseDuration: const Duration(milliseconds: 250),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();

    Future.delayed(widget.duration, () {
      if (mounted && !_isClosing) {
        _close();
      }
    });
  }

  Future<void> _close() async {
    if (_isClosing) return;
    _isClosing = true;
    await _controller.reverse();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SlideTransition(
            position: _slideAnimation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Dismissible(
                key: UniqueKey(),
                direction: DismissDirection.up,
                onDismissed: (_) {
                  _close();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                        color: Colors.black.withValues(alpha: 0.15),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Lottie.asset(
                        animation,
                        repeat: false,
                        fit: BoxFit.contain,
                        width: 50,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.message,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
