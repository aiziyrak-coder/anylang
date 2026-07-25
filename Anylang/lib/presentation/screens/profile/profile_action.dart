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

/// Sofiya AI — savol / muammo / maslahat.
class OpenSofiyaAi extends ProfileAction {}

/// "Akkaunt sozlamalari" — maxfiylik, parol, chiqish.
class OpenAccountSettings extends ProfileAction {}

/// Eski yo'l — umumiy sozlamalar (tizim).
class OpenSettings extends ProfileAction {}

/// Shaxsiy profil — "Tahrirlash" tugmasi bosilganda.
class EditPersonalProfile extends ProfileAction {}

/// Biznes profil — "Tahrirlash" tugmasi bosilganda (S17).
class EditBusinessInfo extends ProfileAction {}

/// Biznes profil — "+ Mahsulot" / e'lon joylash.
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

/// Pull-to-refresh.
class RefreshProfile extends ProfileAction {}

/// Avatar / logo ustiga bosib to'liq ekranda ko'rish.
class OpenProfileAvatar extends ProfileAction {}

/// Kameradan tez avatar almashtirish.
class ChangeAvatarQuick extends ProfileAction {}

/// @username / AnyLang ID nusxalash.
class CopyAnyLangId extends ProfileAction {}

/// Profilni ulashish.
class ShareProfile extends ProfileAction {}

/// Hamyon — obuna / to'lovlar.
class OpenWallet extends ProfileAction {}

/// Business akkaunt / tariflar.
class OpenBusinessAccount extends ProfileAction {}

/// BUSINESS badge — premium afzalliklar sheet.
class ShowBusinessBenefits extends ProfileAction {}

/// Zavod media (rasm/video) preview.
class OpenFactoryMedia extends ProfileAction {
  final String url;
  OpenFactoryMedia(this.url);
}

/// AI Matching kartasi / sheet.
class OpenAiMatching extends ProfileAction {}

class RetryAiMatching extends ProfileAction {}

class OpenMarketAnalytics extends ProfileAction {}

class RetryMarketAnalytics extends ProfileAction {}

/// Business Card QR ko‘rsatish.
class ShowBusinessCardQr extends ProfileAction {}

/// Sozlamalar bo‘limlari.
class OpenSettingsLanguage extends ProfileAction {}

class OpenSettingsTheme extends ProfileAction {}

class OpenSettingsNotifications extends ProfileAction {}

class OpenSettingsPrivacy extends ProfileAction {}

class OpenSettingsSecurity extends ProfileAction {}

class OpenSettingsTranslation extends ProfileAction {}

class OpenSettingsAiAssistant extends ProfileAction {}
