/// Business Card QR — `https://anylang.uz/b/{userId}` / `anylang://b/{userId}`.
class BusinessCardLinks {
  static const webBase = 'https://anylang.uz/b';
  static const schemeHost = 'b';

  static String urlFor(int userId) => '$webBase/$userId';

  static String schemeUrlFor(int userId) => 'anylang://b/$userId';

  static final RegExp idInText = RegExp(
    r'(?:https?://(?:www\.)?anylang\.uz/b/|anylang://b/)(\d+)',
    caseSensitive: false,
  );

  static int? userIdFromText(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final m = idInText.firstMatch(text.trim());
    if (m != null) return int.tryParse(m.group(1)!);
    // Sof raqam (ba'zi skanerlar faqat path qaytaradi)
    final digits = RegExp(r'^(\d{1,12})$').firstMatch(text.trim());
    if (digits != null) return int.tryParse(digits.group(1)!);
    return null;
  }

  static int? userIdFromUri(Uri uri) {
    if (uri.host == 'anylang.uz' &&
        uri.pathSegments.length >= 2 &&
        uri.pathSegments.first == 'b') {
      return int.tryParse(uri.pathSegments[1]);
    }
    if (uri.scheme == 'anylang' && uri.host == 'b') {
      final seg = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.first
          : uri.path.replaceFirst('/', '');
      return int.tryParse(seg);
    }
    return null;
  }
}
