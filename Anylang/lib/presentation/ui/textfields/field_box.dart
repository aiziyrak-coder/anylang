import 'package:flutter/material.dart';
import '../../utils/size_controller.dart';
import '../theme/colors.dart';

/// Kulrang fon + ustki yorliq (label) + ichida ixtiyoriy kontent (input/qiymat).
/// Registration form maydonlari uchun umumiy qobiq.
class FieldBox extends StatelessWidget {
  final String label;
  final Widget child;
  final VoidCallback? onTap;
  final Widget? badge; // label yonida o'ngда chiqadigan ixtiyoriy belgi (masalan "Ixtiyoriy")

  const FieldBox({
    super.key,
    required this.label,
    required this.child,
    this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.dp, vertical: 11.dp),
      decoration: BoxDecoration(
        color: fieldFill,
        borderRadius: BorderRadius.circular(16.dp),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          badge == null
              ? _label()
              : Row(
                  children: [
                    Expanded(child: _label()),
                    badge!,
                  ],
                ),
          SizedBox(height: 4.dp),
          child,
        ],
      ),
    );

    if (onTap == null) return content;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }

  Widget _label() {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11.sp,
        fontWeight: FontWeight.w500,
        color: fieldLabel,
        letterSpacing: 0.2,
      ),
    );
  }
}
