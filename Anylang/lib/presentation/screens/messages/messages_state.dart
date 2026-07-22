import 'package:get/get.dart';
import '../add_friend/add_friend_result.dart';
import 'conversation.dart';

class MessagesState extends GetxController {
  /// Suhbatlar ro'yxati (Screen.initState'da yuklanadi).
  RxList<Conversation> conversations = <Conversation>[].obs;

  /// Qidiruv natijalari (API).
  RxList<Conversation> searchResults = <Conversation>[].obs;

  /// Foydalanuvchi qidiruv natijalari (API).
  RxList<AddFriendResult> userResults = <AddFriendResult>[].obs;

  RxString query = ''.obs;
  RxBool loading = true.obs;
  RxBool searching = false.obs;
}
