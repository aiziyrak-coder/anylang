import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../utils/formatters/date_input_formatter.dart';
import '../../utils/formatters/time_formatter.dart';
import '../../utils/size_controller.dart';
import '../theme/colors.dart';
import 'app_text_field.dart';

/// Tug‘ilgan sana: `kk.oo.yyyy` yozish + ustida o‘qiladigan preview + kalendar.
class BirthDateField extends StatelessWidget {
  final TextEditingController controller;
  final DateTime? date;
  final ValueChanged<DateTime?> onChanged;
  final DateTime firstDate;
  final DateTime lastDate;

  const BirthDateField({
    super.key,
    required this.controller,
    required this.date,
    required this.onChanged,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final preview = date == null ? null : formatBirthDateHuman(date!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (preview != null) ...[
          Text(
            preview,
            style: TextStyle(
              color: c.accentText,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          SizedBox(height: 6.dp),
        ],
        AppTextField(
          label: 'birth_date'.tr,
          hint: 'birth_date_hint'.tr,
          controller: controller,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          inputFormatters: [BirthDateInputFormatter()],
          onChanged: (raw) {
            final parsed = parseDateDots(raw);
            if (parsed == null ||
                parsed.isBefore(firstDate) ||
                parsed.isAfter(lastDate)) {
              onChanged(null);
            } else {
              onChanged(parsed);
            }
          },
          suffix: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _pick(context),
              borderRadius: BorderRadius.circular(20.dp),
              child: Padding(
                padding: EdgeInsets.all(6.dp),
                child: Icon(
                  Icons.calendar_today_outlined,
                  size: 20.dp,
                  color: c.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pick(BuildContext context) async {
    var initial = date ?? DateTime(2000);
    if (initial.isBefore(firstDate)) initial = firstDate;
    if (initial.isAfter(lastDate)) initial = lastDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked == null) return;
    controller.text = formatDateDots(picked);
    onChanged(picked);
  }
}
