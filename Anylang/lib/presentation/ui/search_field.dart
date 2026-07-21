import 'package:flutter/material.dart';
import 'theme/colors.dart';
import '../utils/size_controller.dart';

/// Umumiy qidiruv maydoni (ikonка + input).
class SearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;

  const SearchField({super.key, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14.dp),
        border: Border.all(color: c.surfaceBorder),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16.dp),
      child: Row(
        children: [
          Icon(Icons.search, color: c.textSecondary, size: 20.dp),
          SizedBox(width: 10.dp),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              cursorColor: c.accent,
              style: TextStyle(color: c.textPrimary, fontSize: 15.sp),
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding: EdgeInsets.symmetric(vertical: 16.dp),
                border: InputBorder.none,
                hintText: hint,
                hintStyle: TextStyle(color: c.textFaint, fontSize: 15.sp),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
