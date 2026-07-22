import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/colors.dart';
import '../utils/size_controller.dart';

/// Umumiy qidiruv maydoni (ikonka + input + clear).
class SearchField extends StatefulWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? initialValue;

  const SearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.keyboardType,
    this.inputFormatters,
    this.initialValue,
  });

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14.dp),
        border: Border.all(color: c.surfaceBorder),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12.dp),
      child: Row(
        children: [
          Icon(Icons.search, color: c.textSecondary, size: 20.dp),
          SizedBox(width: 8.dp),
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: (v) {
                setState(() {});
                widget.onChanged(v);
              },
              keyboardType: widget.keyboardType,
              inputFormatters: widget.inputFormatters,
              cursorColor: c.accent,
              style: TextStyle(color: c.textPrimary, fontSize: 15.sp),
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding: EdgeInsets.symmetric(vertical: 16.dp),
                border: InputBorder.none,
                hintText: widget.hint,
                hintStyle: TextStyle(color: c.textFaint, fontSize: 15.sp),
              ),
            ),
          ),
          if (_controller.text.isNotEmpty)
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(minWidth: 32.dp, minHeight: 32.dp),
              onPressed: () {
                _controller.clear();
                setState(() {});
                widget.onChanged('');
              },
              icon: Icon(Icons.close_rounded, color: c.textFaint, size: 18.dp),
            ),
        ],
      ),
    );
  }
}
