import '../../utils/screen_options/my_action.dart';
import '../products/product.dart';

/// Faqat foydalanuvchi profili ekraniga xos action'lar.
class UserProfileAction extends MyAction {}

/// "Yozish" — suhbat ochish.
class WriteMessage extends UserProfileAction {}

/// Do'stlarga qo'shish / so'rov yuborish.
class AddFriendFromProfile extends UserProfileAction {}

/// Yuborilgan do'stlik so'rovini bekor qilish.
class CancelFriendFromProfile extends UserProfileAction {}

/// Kelgan do'stlik so'rovini qabul qilish.
class AcceptFriendFromProfile extends UserProfileAction {}

/// Veb-saytni ochish.
class OpenWebsite extends UserProfileAction {}

/// E'lon (mahsulot) bosilganda.
class OpenListing extends UserProfileAction {
  final Product product;
  OpenListing(this.product);
}
