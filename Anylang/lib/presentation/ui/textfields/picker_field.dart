import 'package:flutter/material.dart';

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
    this.prefix
  });

  @override
  Widget build(BuildContext context) {
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
        GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
                border: Border.all(
                    color: dividerColor
                ),
                borderRadius: BorderRadius.circular(10)
            ),
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if(prefix != null)
                  Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: prefix,
                  ),
                Text(
                  value.isEmpty ? hint : value,
                  style: TextStyle(
                      color: value.isEmpty ? notActiveText : Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.normal
                  ),
                ),
                SizedBox(width: 10)
              ],
            ),
          ),
        )
      ],
    );
  }
}