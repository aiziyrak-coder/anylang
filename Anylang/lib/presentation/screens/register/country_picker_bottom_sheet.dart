import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../ui/theme/colors.dart';
import '../../utils/size_controller.dart';

class CountryOption {
  final String name;
  final String code;
  const CountryOption(this.name, this.code);
}

const List<CountryOption> kCountries = [
  CountryOption('O‘zbekiston', 'UZ'),
  CountryOption('Qozog‘iston', 'KZ'),
  CountryOption('Rossiya', 'RU'),
  CountryOption('Turkiya', 'TR'),
  CountryOption('Qirg‘iziston', 'KG'),
  CountryOption('Tojikiston', 'TJ'),
  CountryOption('AQSH', 'US'),
  CountryOption('Germaniya', 'DE'),
];

/// Davlat tanlash — `(name, code)` juftligini qaytaradi.
Future<CountryOption?> showCountryPickerBottomSheet(BuildContext context) {
  final c = context.appColors;
  return showModalBottomSheet<CountryOption>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return Container(
        decoration: BoxDecoration(
          color: c.isDark ? const Color(0xFF0C2136) : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.dp)),
        ),
        padding: EdgeInsets.fromLTRB(20.dp, 12.dp, 20.dp, 24.dp),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44.dp,
              height: 5.dp,
              decoration: BoxDecoration(
                color: c.outline,
                borderRadius: BorderRadius.circular(5.dp),
              ),
            ),
            SizedBox(height: 16.dp),
            Text(
              'country'.tr,
              style: TextStyle(color: c.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 12.dp),
            ...kCountries.map(
              (item) => Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(ctx, item),
                  borderRadius: BorderRadius.circular(12.dp),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 14.dp, horizontal: 8.dp),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: TextStyle(color: c.textPrimary, fontSize: 15.sp, fontWeight: FontWeight.w500),
                          ),
                        ),
                        Text(
                          item.code,
                          style: TextStyle(color: c.textSecondary, fontSize: 13.sp),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
