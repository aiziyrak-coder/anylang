import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../custom_date_time_picker.dart';

class DateTimePickerField extends StatelessWidget {
  final String label;
  final String value;
  final String hint;
  final DateTime? minTime;
  final DateTime? maxTime;
  final CupertinoDatePickerMode mode;
  final Function(String) selectedDate;

  const DateTimePickerField({
    super.key, required this.label,
    required this.value,
    this.minTime,
    this.maxTime,
    this.mode = CupertinoDatePickerMode.time,
    required this.selectedDate,
    this.hint = "-- : --"
  });

  @override
  Widget build(BuildContext context) {
    final locale = Get.locale ?? const Locale('uz');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.normal
          ),
        ),
        SizedBox(height: 10),
        SizedBox(
          width: double.maxFinite,
          child: CustomDateTImePicker(
            mode: mode,
            iconSize: 20,
            value: value.isEmpty ? hint : value,
            minTime: minTime,
            maxTime: maxTime ?? DateTime.now().add(Duration(days: 10)),
            cancelText: 'cancel'.tr,
            confirmText: 'select_language_confirm'.tr,
            textStyle: TextStyle(
              fontFamily: 'Fustat',
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.normal
            ),
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            locale: Locale(locale.languageCode),
            onChange: (dateTime) {
              selectedDate(dateTime.toString());
            },
          ),
        )
      ],
    );
  }
}
