import '../../utils/screen_options/my_action.dart';
import 'friend.dart';

/// Faqat Do'stlar ekraniga xos action'lar.
class FriendsAction extends MyAction {}

/// Qidiruv matni o'zgarganda.
class FriendsSearchChanged extends FriendsAction {
  final String text;
  FriendsSearchChanged(this.text);
}

/// Do'st bilan suhbat ochilganda.
class OpenChat extends FriendsAction {
  final Friend friend;
  OpenChat(this.friend);
}

/// Yangi do'st qo'shish tugmasi.
class AddFriend extends FriendsAction {}

/// Ro'yxatni yangilash (pull-to-refresh / tab).
class RefreshFriends extends FriendsAction {}

/// Kiruvchi do'stlik so'rovlarini ochish.
class OpenFriendRequests extends FriendsAction {}
