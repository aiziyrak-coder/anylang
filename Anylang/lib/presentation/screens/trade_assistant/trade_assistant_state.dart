import 'package:get/get.dart';

import 'trade_assistant_message.dart';

class TradeAssistantState extends GetxController {
  final RxList<TradeAssistantMessage> messages = <TradeAssistantMessage>[].obs;
  final RxBool sending = false.obs;
  final RxBool showSend = false.obs;
  final RxString error = ''.obs;
  final RxnInt sellerId = RxnInt();
  final RxnString companyName = RxnString();
}
