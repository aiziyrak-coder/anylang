import '../../utils/screen_options/my_action.dart';
import 'friend.dart';
import 'friend_recommendation.dart';
import 'profile_viewer.dart';

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

/// Qo‘ng‘iroq (hozircha mavjud emas).
class OpenFriendCall extends FriendsAction {
  final Friend friend;
  OpenFriendCall(this.friend);
}

/// Jonli tarjima (Live Translate) tabiga o‘tish.
class OpenFriendLive extends FriendsAction {
  final Friend friend;
  OpenFriendLive(this.friend);
}

/// Do‘st mahsulotlarini ochish.
class OpenFriendProducts extends FriendsAction {
  final Friend friend;
  OpenFriendProducts(this.friend);
}

/// Do‘st profilini ochish.
class OpenFriendProfile extends FriendsAction {
  final Friend friend;
  OpenFriendProfile(this.friend);
}

/// Yangi do'st qo'shish tugmasi.
class AddFriend extends FriendsAction {}

/// Ro'yxatni yangilash (pull-to-refresh / tab).
class RefreshFriends extends FriendsAction {}

/// Kiruvchi do'stlik so'rovlarini ochish.
class OpenFriendRequests extends FriendsAction {}

/// Do'stni o'chirish.
class RemoveFriend extends FriendsAction {
  final Friend friend;
  RemoveFriend(this.friend);
}

/// AI tavsiyadan chat ochish (Business Match).
class OpenRecommendedChat extends FriendsAction {
  final FriendRecommendation item;
  OpenRecommendedChat(this.item);
}

/// AI tavsiyadan do‘stlik so‘rovi.
class AddRecommendedFriend extends FriendsAction {
  final FriendRecommendation item;
  AddRecommendedFriend(this.item);
}

/// Premium: kim profilingizni ko‘rdi — profil ochish.
class OpenProfileViewer extends FriendsAction {
  final ProfileViewer item;
  OpenProfileViewer(this.item);
}

/// Basic: Premium ga o‘tish (kim qidirdi teaser).
class OpenProfileViewersPremium extends FriendsAction {}

class FriendsPickCountry extends FriendsAction {}

class FriendsSelectCountry extends FriendsAction {
  final String? code;
  FriendsSelectCountry(this.code);
}

class FriendsPickRole extends FriendsAction {}

class FriendsSelectRole extends FriendsAction {
  final String? code;
  FriendsSelectRole(this.code);
}

class FriendsPickProduct extends FriendsAction {}

class FriendsSelectProduct extends FriendsAction {
  final String? code;
  FriendsSelectProduct(this.code);
}

class FriendsToggleVerified extends FriendsAction {}

class FriendsToggleOnline extends FriendsAction {}

class FriendsClearFilters extends FriendsAction {}
