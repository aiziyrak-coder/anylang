import '../../utils/screen_options/my_action.dart';
import 'profile_account.dart';

/// Faqat Profil (o'z profili) ekraniga xos action'lar.
class ProfileAction extends MyAction {}

/// "Tariflar" tugmasi bosilganda (S16).
class OpenSubscription extends ProfileAction {}

/// AnyLang raqami / katalog / almashtirish.
class OpenNumbers extends ProfileAction {}

/// "Tizim sozlamalari" — til, tema, bildirishnomalar.
class OpenAppSettings extends ProfileAction {}

class OpenSupportFromProfile extends ProfileAction {}

/// "Akkaunt sozlamalari" — maxfiylik, parol, chiqish.
class OpenAccountSettings extends ProfileAction {}

/// Eski yo'l — umumiy sozlamalar (tizim).
class OpenSettings extends ProfileAction {}

/// Shaxsiy profil — "Tahrirlash" tugmasi bosilganda.
class EditPersonalProfile extends ProfileAction {}

/// Biznes profil — "Tahrirlash" tugmasi bosilganda (S17).
class EditBusinessInfo extends ProfileAction {}

/// Biznes profil — "+ Mahsulot" tugmasi bosilganda (S18).
class AddProductRequested extends ProfileAction {}

/// Biznes profil — "Barchasi" (barcha e'lonlarni ko'rish).
class SeeAllListings extends ProfileAction {}

/// Biznes profil — bitta e'lon bosilganda.
class OpenOwnListing extends ProfileAction {
  final OwnListing listing;
  OpenOwnListing(this.listing);
}

/// Profil yuklanishi xato — qayta urinish.
class RetryProfileLoad extends ProfileAction {}

/// Avatar / logo ustiga bosib to'liq ekranda ko'rish.
class OpenProfileAvatar extends ProfileAction {}
