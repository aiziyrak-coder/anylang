import 'package:get/get.dart';
import 'friend.dart';

class FriendsState extends GetxController {
  /// Do'stlar ro'yxati (Screen.initState'da yuklanadi).
  RxList<Friend> friends = <Friend>[].obs;

  /// Qidiruv matni.
  RxString query = ''.obs;
}
