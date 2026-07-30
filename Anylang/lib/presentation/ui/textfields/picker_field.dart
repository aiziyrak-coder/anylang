import 'package:flutter/material.dart';

import '../../utils/size_controller.dart';
import '../theme/colors.dart';

class PickerField extends StatelessWidget {
  final String label;
  final String hint;
  final String value;
  final VoidCallback onTap;
  final Widget? prefix;

  const PickerField({
    super.key,
    required this.label,
    required this.hint,
    required this.value,
    required this.onTap,
    this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final radius = BorderRadius.circular(10.dp);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 16.sp,
            fontWeight: FontWeight.normal,
          ),
        ),
        SizedBox(height: 10.dp),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: c.outline),
                borderRadius: radius,
              ),
              padding: EdgeInsets.symmetric(horizontal: 14.dp, vertical: 14.dp),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (prefix != null)
                    Padding(
                      padding: EdgeInsets.only(right: 10.dp),
                      child: prefix,
                    ),
                  Expanded(
                    child: Text(
                      value.isEmpty ? hint : value,
                      style: TextStyle(
                        color: value.isEmpty ? c.textFaint : c.textPrimary,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                  SizedBox(width: 10.dp),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
