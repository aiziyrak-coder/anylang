import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

enum SnackBarStatus {
  success,
  error,
  warning,
}

class MySnackBar {

  static OverlayEntry? _current;

  /// Ilova ochilishi / resume da eski toastni tozalash.
  static void dismiss() {
    try {
      _current?.remove();
    } catch (_) {}
    _current = null;
  }

  static void show({
    required BuildContext context,
    required SnackBarStatus status,
    required String title,
    required String message,
    Duration duration = const Duration(seconds: 3),
    OverlayState? overlay,
  }) {

    dismiss();

    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(

      builder: (_) {

        return _AnimatedSnackBar(
          title: title,
          message: message,
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

    final overlayState = overlay
        ?? Navigator.maybeOf(context, rootNavigator: true)?.overlay
        ?? Overlay.maybeOf(context, rootOverlay: true);
    if (overlayState == null) return;

    _current = overlayEntry;
    overlayState.insert(overlayEntry);
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
  State<_AnimatedSnackBar> createState() =>
      _AnimatedSnackBarState();
}

class _AnimatedSnackBarState
    extends State<_AnimatedSnackBar>
    with SingleTickerProviderStateMixin {

  late final AnimationController _controller;

  late final Animation<Offset> _slideAnimation;

  Color backgroundColor = Colors.green;
  String animation = "assets/animations/anim_success.json";

  bool _isClosing = false;

  @override
  void initState() {

    switch(widget.status) {
      case SnackBarStatus.success:
        backgroundColor = Colors.green;
        animation = "assets/animations/success_snack.json";
        break;
      case SnackBarStatus.error:
        backgroundColor = Colors.red;
        animation = "assets/animations/snack_error.json";
        break;
      case SnackBarStatus.warning:
        backgroundColor = Colors.orange;
        animation = "assets/animations/anim_warning.json";
        break;
    }

    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      reverseDuration:
      const Duration(milliseconds: 250),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
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
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
              ),

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

                    borderRadius:
                    BorderRadius.circular(20),

                    boxShadow: [
                      BoxShadow(
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                        color: Colors.black.withOpacity(0.15),
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
                          crossAxisAlignment:
                          CrossAxisAlignment.start,

                          mainAxisSize:
                          MainAxisSize.min,

                          children: [

                            Text(
                              widget.title,

                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight:
                                FontWeight.w700,
                              ),
                            ),

                            const SizedBox(height: 2),

                            Text(
                              widget.message,

                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight:
                                FontWeight.w400,
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