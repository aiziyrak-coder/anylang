import 'package:get/get.dart';
import 'support_message.dart';

class SupportChatState extends GetxController {
  final RxList<SupportMessage> messages = <SupportMessage>[].obs;
  final RxBool sending = false.obs;
  final RxBool showSend = false.obs;
  final RxString error = ''.obs;
}
