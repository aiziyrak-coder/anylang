import 'package:get/get.dart';
import 'conversation.dart';

class MessagesState extends GetxController {
  /// Suhbatlar ro'yxati (Screen.initState'da yuklanadi).
  RxList<Conversation> conversations = <Conversation>[].obs;

  /// Qidiruv matni.
  RxString query = ''.obs;
}
