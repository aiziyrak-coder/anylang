import 'dart:developer';

String formatSecondToMinute(int seconds) {
  final duration = Duration(seconds: seconds);

  String twoDigits(int n) => n.toString().padLeft(2, '0');

  final minutes = twoDigits(duration.inMinutes.remainder(60));
  final secs = twoDigits(duration.inSeconds.remainder(60));

  return "$minutes:$secs";
}


String formatDateToIso(String date) {

  final value = date.trim();

  /// yyyy-MM-dd
  final isoRegex =
  RegExp(r'^\d{4}-\d{2}-\d{2}$');

  if (isoRegex.hasMatch(value)) {
    return value;
  }

  List<String> parts;

  /// dd.MM.yyyy
  if (value.contains('.')) {

    parts = value.split('.');

    /// dd-MM-yyyy
  } else if (value.contains('-')) {

    parts = value.split('-');

  } else {

    throw FormatException(
      "Date = $date format noto‘g‘ri.\n"
          "Kutilgan formatlar:\n"
          "dd.MM.yyyy\n"
          "dd-MM-yyyy\n"
          "yyyy-MM-dd",
    );
  }

  if (parts.length != 3) {

    throw FormatException(
      "Date = $date format noto‘g‘ri.\n"
          "Kutilgan formatlar:\n"
          "dd.MM.yyyy\n"
          "dd-MM-yyyy\n"
          "yyyy-MM-dd",
    );
  }

  final day =
  parts[0].padLeft(2, '0');

  final month =
  parts[1].padLeft(2, '0');

  final year =
  parts[2];

  return "$year-$month-$day";
}

String formatDateFromIso(String date) {
  final parts = date.split('-');

  if (parts.length != 3) {
    throw FormatException("Date = $date format noto‘g‘ri. Kutilgan format: yyyy-MM-dd");
  }

  final year = parts[0];
  final month = parts[1].padLeft(2, '0');
  final day = parts[2].padLeft(2, '0');

  return "$day-$month-$year";
}

String datePickerToUI(String? date) {
  if (date == null || date.trim().isEmpty) return '';

  try {
    final parsed = DateTime.parse(date);

    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final year = parsed.year.toString();

    return '$day-$month-$year';
  } catch (_) {
    return '';
  }
}

String timePickerToUI(String? date) {
  if (date == null || date.trim().isEmpty) return '';

  try {
    final parsed = DateTime.parse(date);

    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');

    return '$hour : $minute';
  } catch (_) {
    return '';
  }
}

String dateTimePickerToUI(String? date) {
  if (date == null || date.trim().isEmpty) return '';

  try {
    final parsed = DateTime.parse(date);

    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final year = parsed.year.toString();

    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');

    return '$day-$month-$year $hour : $minute';
  } catch (_) {
    return '';
  }
}

/// `DateTime` → "15.03.2027" (register, profil kabi ekranlarda umumiy sana ko'rinishi).
String formatDateDots(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

String formatIsoDateToHHmm(String? isoTime) {
  if (isoTime == null || isoTime.trim().isEmpty) {
    return "";
  }

  final parsed = DateTime.tryParse(isoTime);

  if (parsed == null) {
    return "";
  }

  if (parsed.hour == 0 &&
      parsed.minute == 0 &&
      parsed.second == 0) {
    return "";
  }

  final local = parsed.toLocal();

  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');

  return '$hour:$minute';
}