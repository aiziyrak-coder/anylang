import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../utils/formatters/phone_input_formatter.dart';
import '../../utils/size_controller.dart';
import '../theme/colors.dart';

class PhoneNumberInput extends StatefulWidget {
  final TextEditingController controller;
  const PhoneNumberInput({super.key, required this.controller});

  @override
  State<PhoneNumberInput> createState() => _PhoneNumberInputState();
}

class _PhoneNumberInputState extends State<PhoneNumberInput> {
  final FocusNode _focusNode = FocusNode();

  bool isFocused = false;

  @override
  void initState() {
    super.initState();

    _focusNode.addListener(() {
      setState(() {
        isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    // controller LoginState'ga tegishli — bu yerda dispose qilinmaydi.
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'phone_number'.tr,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
            color: textDark,
          ),
        ),
        SizedBox(height: 8.dp),
        Container(
          height: 60.dp,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12.dp),
            border: Border.all(
              color: isFocused ? bluePrimary : fieldBorder,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.dp),
                child: Text(
                  "+998",
                  style: TextStyle(
                    fontSize: 18.sp,
                    color: textDark,
                  ),
                ),
              ),

              Container(
                width: 1,
                height: double.infinity,
                color: fieldBorder,
              ),

              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    PhoneInputFormatter(),
                  ],
                  style: TextStyle(
                    fontSize: 18.sp,
                  ),
                  decoration: InputDecoration(
                    hintText: "00 123 - 45 - 67",
                    hintStyle: TextStyle(
                      color: textMuted,
                      fontSize: 18.sp,
                    ),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16.dp),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
