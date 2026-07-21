import 'package:flutter/material.dart';
import 'buttons/my_icon_button.dart';
import 'theme/colors.dart';
import '../utils/size_controller.dart';

/// Orqaga qaytish tugmasi + sarlavhali yuqori panel. `title` chaqiruvchi
/// tomonda `.tr` bilan beriladi, `onBack` — odatda `sendAction(Back())`.
class AppTopBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final Widget? trailing;
  final TextStyle? titleStyle;
  final IconData leadingIcon;

  const AppTopBar({
    super.key,
    required this.title,
    required this.onBack,
    this.trailing,
    this.titleStyle,
    this.leadingIcon = Icons.arrow_back_ios_new,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Row(
      children: [
        MyIconButton(
          onClick: onBack,
          icon: leadingIcon,
          iconColor: c.textPrimary,
          iconSize: 20.dp,
          backgroundColor: Colors.transparent,
          borderRadius: 12.dp,
          padding: EdgeInsets.all(6.dp),
        ),
        SizedBox(width: 6.dp),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: titleStyle ??
                TextStyle(
                  color: c.textPrimary,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}
