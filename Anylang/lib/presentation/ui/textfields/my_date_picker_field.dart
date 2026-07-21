import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import '../../utils/size_controller.dart';
import '../custom_date_time_picker.dart';
import '../theme/colors.dart';
import 'field_box.dart';

/// Sana tanlash maydoni — joriy form uslubida (FieldBox: kulrang fon, ustki label,
/// kalendar ikonка) + loyihaning `CustomDateTImePicker` spinner popup'i.
class MyDatePickerField extends StatelessWidget {
  final String label;
  final String hint;
  final DateTime? date;
  final DateTime? minTime;
  final DateTime? maxTime;
  final void Function(DateTime) onChanged;

  const MyDatePickerField({
    super.key,
    required this.label,
    required this.hint,
    required this.date,
    required this.onChanged,
    this.minTime,
    this.maxTime,
  });

  @override
  Widget build(BuildContext context) {
    return CustomDateTImePicker(
      mode: CupertinoDatePickerMode.date,
      initTime: date ?? maxTime ?? DateTime.now(),
      minTime: minTime,
      maxTime: maxTime ?? DateTime.now(),
      // locale uzatilmaydi — app'ning custom kodlari ('us_US') Cupertino
      // localizations'da yo'q; ambient Localizations ishlatiladi.
      cancelText: 'cancel'.tr,
      confirmText: 'confirm'.tr,
      timeWidgetBuilder: (_) => _fieldVisual(),
      onChange: onChanged,
    );
  }

  Widget _fieldVisual() {
    return FieldBox(
      label: label,
      child: Row(
        children: [
          Expanded(
            child: Text(
              date != null ? _format(date!) : hint,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w500,
                color: date != null ? textDark : notActiveText,
              ),
            ),
          ),
          SvgPicture.asset('assets/icons/ic_calendar.svg', width: 20.dp, height: 20.dp),
        ],
      ),
    );
  }

  String _format(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}
