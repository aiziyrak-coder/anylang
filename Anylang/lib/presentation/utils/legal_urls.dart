import 'package:url_launcher/url_launcher.dart';

/// AnyLang huquqiy sahifalari (sayt).
class LegalUrls {
  LegalUrls._();

  static const privacy = 'https://anylang.uz/privacy/';
  static const terms = 'https://anylang.uz/terms/';

  static Future<bool> openPrivacy() => open(privacy);

  static Future<bool> openTerms() => open(terms);

  static Future<bool> open(String url) async {
    final uri = Uri.parse(url);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
