import 'package:get/get.dart';
import 'friend.dart';

class FriendsState extends GetxController {
  /// Do'stlar ro'yxati (Screen.initState'da yuklanadi).
  RxList<Friend> friends = <Friend>[].obs;
  RxString query = ''.obs;
  RxBool loading = true.obs;

  /// Kiruvchi do'st so'rovlari soni (pastki nav badge uchun).
  RxInt pendingCount = 0.obs;
}
