import 'package:get/get.dart';
import '../add_friend/add_friend_result.dart';
import 'conversation.dart';

/// Xabarlar filter bari: faqat bitta tanlov.
enum MessagesListFilter { all, unread, chats, groups }

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

  /// Bir vaqtda faqat bitta filter.
  final Rx<MessagesListFilter> listFilter = MessagesListFilter.all.obs;

  /// Ro‘yxat multi-select.
  final RxBool selecting = false.obs;
  final RxSet<int> selectedIds = <int>{}.obs;
}
