import 'package:flutter/material.dart';
import 'package:get/get.dart';

void showAppError(Object? message) {
  final text = _normalize(message);
  if (text.isEmpty) return;
  _showSnack(
    title: 'error'.tr == 'error' ? 'Xato' : 'error'.tr,
    message: text,
    background: const Color(0xFFB42318),
  );
}

void showAppMessage(Object? message) {
  final text = _normalize(message);
  if (text.isEmpty) return;
  _showSnack(
    title: 'success'.tr == 'success' ? 'OK' : 'success'.tr,
    message: text,
    background: const Color(0xFF027A48),
  );
}

String _normalize(Object? message) {
  if (message == null) return '';
  final text = message.toString().trim();
  if (text == 'null' || text == 'Instance of') return '';
  return text;
}

void _showSnack({
  required String title,
  required String message,
  required Color background,
}) {
  // Close previous snack to avoid stacked spam
  if (Get.isSnackbarOpen) {
    Get.closeCurrentSnackbar();
  }

  Get.rawSnackbar(
    titleText: Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
    ),
    messageText: Text(
      message,
      style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.35),
      maxLines: 5,
      overflow: TextOverflow.ellipsis,
    ),
    backgroundColor: background.withValues(alpha: 0.95),
    borderRadius: 14,
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    snackPosition: SnackPosition.BOTTOM,
    duration: Duration(milliseconds: message.length > 80 ? 4500 : 3200),
    isDismissible: true,
    dismissDirection: DismissDirection.horizontal,
    snackStyle: SnackStyle.FLOATING,
  );
}
