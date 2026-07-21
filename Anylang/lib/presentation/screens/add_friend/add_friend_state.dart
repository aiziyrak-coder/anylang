import 'package:get/get.dart';
import 'add_friend_result.dart';

class AddFriendState extends GetxController {
  /// Qidiruv natijalari (Screen.initState'da yuklanadi).
  RxList<AddFriendResult> results = <AddFriendResult>[].obs;

  /// Qidiruv matni.
  RxString query = ''.obs;
}
