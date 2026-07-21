import '../../utils/screen_options/my_action.dart';
import '../products/product.dart';

/// Faqat foydalanuvchi profili ekraniga xos action'lar.
class UserProfileAction extends MyAction {}

/// "Yozish" — suhbat ochish.
class WriteMessage extends UserProfileAction {}

/// Telefon qilish.
class CallUser extends UserProfileAction {}

/// Veb-saytni ochish.
class OpenWebsite extends UserProfileAction {}

/// E'lon (mahsulot) bosilganda.
class OpenListing extends UserProfileAction {
  final Product product;
  OpenListing(this.product);
}
