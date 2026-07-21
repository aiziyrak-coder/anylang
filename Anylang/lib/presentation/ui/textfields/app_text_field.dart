import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../../utils/size_controller.dart';

/// Label + fill + border ko'rinishidagi umumiy input (login/register uchun).
/// Fokusda chegara lime bo'ladi. Parol uchun ko'z (show/hide) tugmasi.
class AppTextField extends StatefulWidget {
  final String label;
  final String hint;
  final TextEditingController? controller;
  final bool isPassword;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final String? prefixText;
  final ValueChanged<String>? onChanged;

  const AppTextField({
    super.key,
    required this.label,
    required this.hint,
    this.controller,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.prefixText,
    this.onChanged,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  final FocusNode _focus = FocusNode();
  late bool _obscure = widget.isPassword;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final focused = _focus.hasFocus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8.dp),
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(14.dp),
            border: Border.all(
              color: focused ? c.accent : c.surfaceBorder,
              width: 1.4,
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: 16.dp),
          child: Row(
            crossAxisAlignment: widget.maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  obscureText: _obscure,
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.textInputAction,
                  cursorColor: c.accent,
                  maxLines: widget.isPassword ? 1 : widget.maxLines,
                  minLines: widget.minLines,
                  maxLength: widget.maxLength,
                  onChanged: widget.onChanged,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 18.dp),
                    border: InputBorder.none,
                    hintText: widget.hint,
                    hintStyle: TextStyle(
                      color: c.textFaint,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w500,
                    ),
                    prefixText: widget.prefixText,
                    prefixStyle: TextStyle(
                      color: c.textPrimary,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  buildCounter: widget.maxLength == null
                      ? null
                      : (context, {required currentLength, required isFocused, maxLength}) => Padding(
                            padding: EdgeInsets.only(top: 4.dp),
                            child: Text(
                              '$currentLength / $maxLength',
                              style: TextStyle(color: c.textFaint, fontSize: 11.sp),
                            ),
                          ),
                ),
              ),
              if (widget.isPassword)
                InkResponse(
                  onTap: () => setState(() => _obscure = !_obscure),
                  radius: 22.dp,
                  child: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: c.textSecondary,
                    size: 20.dp,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
