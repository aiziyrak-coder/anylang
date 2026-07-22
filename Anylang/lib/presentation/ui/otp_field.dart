import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/colors.dart';
import '../utils/size_controller.dart';

/// Qayta ishlatiladigan OTP (kod) kiritish maydoni — [length] ta katakcha.
/// Ichkarida bitta yashirin `TextField`, kataklar shu qiymatni aks ettiradi.
class OtpField extends StatefulWidget {
  final int length;
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;

  const OtpField({
    super.key,
    this.length = 6,
    this.initialValue,
    this.onChanged,
    this.onCompleted,
  });

  @override
  State<OtpField> createState() => _OtpFieldState();
}

class _OtpFieldState extends State<OtpField> {
  late final TextEditingController _controller;
  final FocusNode _focus = FocusNode();

  String get _value => _controller.text;

  @override
  void initState() {
    super.initState();
    final initial = (widget.initialValue ?? '').replaceAll(RegExp(r'\D'), '');
    _controller = TextEditingController(
      text: initial.length > widget.length
          ? initial.substring(0, widget.length)
          : initial,
    );
    _controller.addListener(_onChanged);
    _focus.addListener(_onFocusChange);
    if (_controller.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onChanged?.call(_controller.text);
        if (_controller.text.length == widget.length) {
          widget.onCompleted?.call(_controller.text);
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant OtpField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = (widget.initialValue ?? '').replaceAll(RegExp(r'\D'), '');
    final clipped = next.length > widget.length
        ? next.substring(0, widget.length)
        : next;
    if (clipped.isNotEmpty && clipped != _controller.text) {
      _controller.text = clipped;
      _controller.selection = TextSelection.collapsed(offset: clipped.length);
    }
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) return;
    void ensure() {
      if (!mounted || !_focus.hasFocus) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: 0.2,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => ensure());
    Future<void>.delayed(const Duration(milliseconds: 320), ensure);
  }

  void _onChanged() {
    setState(() {});
    widget.onChanged?.call(_value);
    if (_value.length == widget.length) {
      widget.onCompleted?.call(_value);
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Stack(
      children: [
        // Ko'rinadigan kataklar.
        Row(
          children: List.generate(widget.length, (i) {
              final filled = i < _value.length;
              final active = i == _value.length && _focus.hasFocus;
              final highlighted = filled || active;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == widget.length - 1 ? 0 : 10.dp),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(14.dp),
                        border: Border.all(
                          color: highlighted ? c.accent : c.surfaceBorder,
                          width: highlighted ? 1.6 : 1,
                        ),
                        boxShadow: active
                            ? [
                                BoxShadow(
                                  color: kLime.withValues(alpha: 0.25),
                                  blurRadius: 12.dp,
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        filled ? _value[i] : '',
                        style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          // Ustidagi shaffof kiritish maydoni — bosilganda fokus oladi.
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                keyboardType: TextInputType.number,
                maxLength: widget.length,
                showCursor: false,
                enableInteractiveSelection: false,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: Colors.transparent),
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
        ],
      );
  }
}
