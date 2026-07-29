/// Pul formatlash (UI).
String formatMoneyAmount(
  Object? raw, {
  String currency = 'UZS',
}) {
  final n = _toNum(raw);
  if (n == null) return raw?.toString() ?? '';
  final currencyUpper = currency.toUpperCase();
  if (currencyUpper == 'UZS') {
    final whole = n.round();
    return "${_groupDigits(whole)} so‘m";
  }
  if (currencyUpper == 'USD') {
    return '\$${_fixed2(n)}';
  }
  return '${_fixed2(n)} $currencyUpper';
}

String formatMoneyPlain(Object? raw, {bool whole = false}) {
  final n = _toNum(raw);
  if (n == null) return raw?.toString() ?? '';
  if (whole) return _groupDigits(n.round());
  return _groupDigitsFixed(n);
}

num? _toNum(Object? raw) {
  if (raw is num) return raw;
  if (raw is String) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.\-]'), '');
    return num.tryParse(cleaned);
  }
  return null;
}

String _fixed2(num n) => n.toStringAsFixed(2);

String _groupDigits(int n) {
  final neg = n < 0;
  final s = (neg ? -n : n).toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final fromEnd = s.length - i;
    if (i > 0 && fromEnd % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return neg ? '-$buf' : buf.toString();
}

String _groupDigitsFixed(num n) {
  final fixed = n.toStringAsFixed(2);
  final parts = fixed.split('.');
  final whole = int.tryParse(parts[0]) ?? 0;
  return '${_groupDigits(whole)}.${parts[1]}';
}
