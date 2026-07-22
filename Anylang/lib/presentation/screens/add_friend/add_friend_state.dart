import 'package:get/get.dart';
import 'add_friend_payload.dart';
import 'add_friend_result.dart';

class AddFriendState extends GetxController {
  /// Qidiruv natijalari.
  RxList<AddFriendResult> results = <AddFriendResult>[].obs;

  /// Yuborilgan, hali qabul qilinmagan (va rad etilgan) so'rovlar — do'stlar rejimi.
  RxList<AddFriendResult> sentRequests = <AddFriendResult>[].obs;

  /// Qidiruv matni.
  RxString query = ''.obs;

  /// API qidiruv ketmoqda.
  RxBool searching = false.obs;

  /// Yuborilgan so'rovlar yuklanmoqda.
  RxBool loadingSent = false.obs;

  /// Xabarlar (+) yoki Do'stlar (so'rov) rejimi — initState'da beriladi.
  AddFriendMode mode = AddFriendMode.chat;
}
