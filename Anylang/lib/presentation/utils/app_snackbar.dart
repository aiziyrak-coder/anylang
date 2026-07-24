import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../ui/my_snackbar.dart';

/// Prefer a navigator/route context — Get.overlayContext is _Theater and
/// breaks Overlay.of / insert.
BuildContext? _snackContext() {
  final navCtx = Get.key.currentContext;
  if (navCtx != null && navCtx.mounted) return navCtx;
  final ctx = Get.context;
  if (ctx != null && ctx.mounted) return ctx;
  return Get.overlayContext;
}

OverlayState? _overlayState(BuildContext context) {
  return Navigator.maybeOf(context, rootNavigator: true)?.overlay
      ?? Get.key.currentState?.overlay
      ?? Overlay.maybeOf(context, rootOverlay: true);
}

void showAppError(Object? message) {
  _show(message, SnackBarStatus.error, 'error'.tr, textLengthAware: true);
}

void showAppMessage(Object? message) {
  _show(
    message,
    SnackBarStatus.success,
    'success'.tr,
    duration: const Duration(milliseconds: 1800),
  );
}

void showAppWarning(Object? message) {
  _show(
    message,
    SnackBarStatus.warning,
    'warning'.tr,
    duration: const Duration(milliseconds: 2200),
  );
}

void _show(
  Object? message,
  SnackBarStatus status,
  String title, {
  Duration? duration,
  bool textLengthAware = false,
}) {
  final text = _normalize(message);
  if (text.isEmpty) return;
  final context = _snackContext();
  if (context == null) return;
  final overlay = _overlayState(context);
  if (overlay == null) return;
  try {
    MySnackBar.show(
      context: context,
      status: status,
      title: title,
      message: text,
      duration: duration ??
          Duration(milliseconds: textLengthAware && text.length > 80 ? 3500 : 2500),
      overlay: overlay,
    );
  } catch (_) {
    // Never break callers (e.g. NetworkClient success path).
  }
}

String _normalize(Object? message) {
  if (message == null) return '';
  final text = message.toString().trim();
  if (text.isEmpty || text == 'null' || text.startsWith('Instance of')) {
    return '';
  }
  return text;
}
