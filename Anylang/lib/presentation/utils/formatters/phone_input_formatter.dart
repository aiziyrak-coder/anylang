import 'package:flutter/services.dart';

class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    String digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    if (digits.length > 9) {
      digits = digits.substring(0, 9);
    }

    String formatted = "";

    if (digits.isNotEmpty) {
      formatted += "(";
    }

    if (digits.length >= 2) {
      formatted += "${digits.substring(0, 2)}) ";
    } else {
      formatted += digits;
    }

    if (digits.length > 2) {
      formatted += digits.substring(2, digits.length >= 5 ? 5 : digits.length);
    }

    if (digits.length > 5) {
      formatted += " - ${digits.substring(5, digits.length >= 7 ? 7 : digits.length)}";
    }

    if (digits.length > 7) {
      formatted += " - ${digits.substring(7, digits.length)}";
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

String unmaskPhone(String input) {
  return input.replaceAll(RegExp(r'\D'), '');
}

String formatPhoneNumber(String? phone, {bool showFull = true}) {
  if(phone == null) return "Nomalum";
  final cleaned = phone.replaceAll(RegExp(r'\D'), '');

  if (cleaned.length != 12) {
    return phone;
  }

  return '+${cleaned.substring(0, 3)} '
      '${cleaned.substring(3, 5)} '
      '${cleaned.substring(5, 8)} '
      '${showFull ? cleaned.substring(8, 10) : "**"} '
      '${showFull ? cleaned.substring(10, 12) : "**"}';
}