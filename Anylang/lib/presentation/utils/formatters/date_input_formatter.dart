import 'package:flutter/services.dart';
import 'package:get/get.dart';

/// `kk.oo.yyyy` — faqat raqamlar; 2 va 4-raqamdan keyin nuqta qo‘yiladi.
class BirthDateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 8) {
      digits = digits.substring(0, 8);
    }

    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 2 || i == 4) buf.write('.');
      buf.write(digits[i]);
    }
    final formatted = buf.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// `12.09.1998` → [DateTime], noto‘g‘ri bo‘lsa `null`.
DateTime? parseDateDots(String input) {
  final m = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$').firstMatch(input.trim());
  if (m == null) return null;
  final day = int.parse(m.group(1)!);
  final month = int.parse(m.group(2)!);
  final year = int.parse(m.group(3)!);
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final d = DateTime(year, month, day);
  // 31.02.2000 kabi noto‘g‘ri kunlarni rad etish.
  if (d.year != year || d.month != month || d.day != day) return null;
  return d;
}

/// `DateTime` → lokalizatsiyalangan "1998 yil 12-sentabr".
String formatBirthDateHuman(DateTime d) {
  final monthKey = 'month_${d.month}';
  var month = monthKey.tr;
  // uz/ru: "12-sentabr" / "12 сентября"
  month = month.toLowerCase();
  return 'birth_date_human'.trParams({
    'year': '${d.year}',
    'day': '${d.day}',
    'month': month,
  });
}
