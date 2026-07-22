import 'package:get/get.dart';
import 'conversation.dart';

class MessagesState extends GetxController {
  /// Suhbatlar ro'yxati (Screen.initState'da yuklanadi).
  RxList<Conversation> conversations = <Conversation>[].obs;

  /// Qidiruv natijalari (API).
  RxList<Conversation> searchResults = <Conversation>[].obs;

  RxString query = ''.obs;
  RxBool loading = true.obs;
  RxBool searching = false.obs;
}
