import 'package:get/get.dart';

import '../ui/my_snackbar.dart';

void showAppError(Object? message) {
  final text = _normalize(message);
  if (text.isEmpty) return;
  MySnackBar.show(
    status: SnackBarStatus.error,
    title: 'error'.tr,
    message: text,
    duration: Duration(milliseconds: text.length > 80 ? 3500 : 2500),
  );
}

void showAppMessage(Object? message) {
  final text = _normalize(message);
  if (text.isEmpty) return;
  MySnackBar.show(
    status: SnackBarStatus.success,
    title: 'success'.tr,
    message: text,
    duration: const Duration(milliseconds: 1800),
  );
}

void showAppWarning(Object? message) {
  final text = _normalize(message);
  if (text.isEmpty) return;
  MySnackBar.show(
    status: SnackBarStatus.warning,
    title: 'warning'.tr,
    message: text,
    duration: const Duration(milliseconds: 2200),
  );
}

String _normalize(Object? message) {
  if (message == null) return '';
  final text = message.toString().trim();
  if (text.isEmpty || text == 'null' || text.startsWith('Instance of')) {
    return '';
  }
  return text;
}
