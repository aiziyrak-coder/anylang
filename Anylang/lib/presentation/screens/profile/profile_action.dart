import '../../utils/screen_options/my_action.dart';
import 'profile_account.dart';

/// Faqat Profil (o'z profili) ekraniga xos action'lar.
class ProfileAction extends MyAction {}

/// "Tariflar" tugmasi bosilganda (S16).
class OpenSubscription extends ProfileAction {}

/// "Sozlamalar" tugmasi bosilganda (S15).
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
