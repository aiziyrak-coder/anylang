import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../ui/buttons/primary_button.dart';
import '../ui/textfields/app_text_field.dart';
import '../ui/theme/colors.dart';
import '../utils/size_controller.dart';

/// Profil bio tahrirlash (maks. 300 belgi). Natija — saqlangan matn yoki null (bekor).
Future<String?> showEditBioBottomSheet(
  BuildContext context, {
  String initial = '',
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _EditBioSheet(initial: initial),
  );
}

class _EditBioSheet extends StatefulWidget {
  final String initial;

  const _EditBioSheet({required this.initial});

  @override
  State<_EditBioSheet> createState() => _EditBioSheetState();
}

class _EditBioSheetState extends State<_EditBioSheet> {
  static const _max = 300;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final start = widget.initial.trim();
    _controller = TextEditingController(
      text: start.length > _max ? start.substring(0, _max) : start,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.dp)),
        ),
        padding: EdgeInsets.fromLTRB(20.dp, 14.dp, 20.dp, 24.dp),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44.dp,
                  height: 5.dp,
                  decoration: BoxDecoration(
                    color: c.outline,
                    borderRadius: BorderRadius.circular(5.dp),
                  ),
                ),
              ),
              SizedBox(height: 16.dp),
              Text(
                'profile_bio_edit_title'.tr,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6.dp),
              Text(
                'profile_bio_hint'.tr,
                style: TextStyle(color: c.textSecondary, fontSize: 13.sp),
              ),
              SizedBox(height: 14.dp),
              AppTextField(
                controller: _controller,
                label: 'profile_bio'.tr,
                hint: 'profile_bio_placeholder'.tr,
                maxLines: 5,
                minLines: 3,
                maxLength: _max,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(_max),
                ],
              ),
              SizedBox(height: 16.dp),
              PrimaryButton(
                text: 'common_save'.tr,
                onTap: () => Navigator.pop(context, _controller.text.trim()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
