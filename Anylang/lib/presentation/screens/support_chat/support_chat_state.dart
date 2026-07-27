import 'package:get/get.dart';
import 'support_message.dart';

class SupportChatState extends GetxController {
  final RxList<SupportMessage> messages = <SupportMessage>[].obs;
  final RxBool sending = false.obs;
  final RxBool showSend = false.obs;
  final RxString error = ''.obs;
  final RxBool loadingSession = false.obs;
  final RxInt sessionId = 0.obs;
  final RxString sessionStatus = ''.obs;
  final RxBool showRatingPrompt = false.obs;
  final RxInt selectedRating = 0.obs;
  final RxBool ratingSubmitting = false.obs;
  /// Composer matnini tozalash (yuborish muvaffaqiyatli bo‘lganda).
  final RxInt composerClearToken = 0.obs;
}
