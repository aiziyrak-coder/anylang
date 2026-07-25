import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../ui/buttons/primary_button.dart';
import '../ui/textfields/app_text_field.dart';
import '../ui/theme/colors.dart';
import '../utils/size_controller.dart';
import '../screens/business_feed/feed_post.dart';

/// Yangi Business Feed posti yaratish (pastdan sheet).
Future<({String postType, String title, String body})?> showCreateFeedBottomSheet(
  BuildContext context, {
  String initialType = 'discount',
}) {
  return showModalBottomSheet<({String postType, String title, String body})>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CreateFeedSheet(initialType: initialType),
  );
}

class _CreateFeedSheet extends StatefulWidget {
  final String initialType;
  const _CreateFeedSheet({required this.initialType});

  @override
  State<_CreateFeedSheet> createState() => _CreateFeedSheetState();
}

class _CreateFeedSheetState extends State<_CreateFeedSheet> {
  late String _type;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _titleCtrl = TextEditingController();
    _bodyCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: c.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.dp)),
        ),
        padding: EdgeInsets.fromLTRB(20.dp, 12.dp, 20.dp, 20.dp),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40.dp,
                    height: 4.dp,
                    decoration: BoxDecoration(
                      color: c.textFaint,
                      borderRadius: BorderRadius.circular(2.dp),
                    ),
                  ),
                ),
                SizedBox(height: 16.dp),
                Text(
                  'feed_create_title'.tr,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6.dp),
                Text(
                  'feed_create_hint'.tr,
                  style: TextStyle(color: c.textSecondary, fontSize: 13.sp),
                ),
                SizedBox(height: 14.dp),
                Wrap(
                  spacing: 8.dp,
                  runSpacing: 8.dp,
                  children: [
                    for (final t in kFeedPostTypes)
                      _TypeChip(
                        label: feedTypeLabelKey(t).tr,
                        selected: _type == t,
                        onTap: () => setState(() => _type = t),
                      ),
                  ],
                ),
                SizedBox(height: 16.dp),
                AppTextField(
                  label: 'feed_field_title'.tr,
                  hint: 'feed_field_title_hint'.tr,
                  controller: _titleCtrl,
                ),
                SizedBox(height: 12.dp),
                AppTextField(
                  label: 'feed_field_body'.tr,
                  hint: 'feed_field_body_hint'.tr,
                  controller: _bodyCtrl,
                  maxLines: 4,
                  minLines: 2,
                  textInputAction: TextInputAction.newline,
                ),
                SizedBox(height: 20.dp),
                PrimaryButton(
                  text: 'feed_publish'.tr,
                  onTap: () {
                    final title = _titleCtrl.text.trim();
                    if (title.length < 2) return;
                    Navigator.pop(
                      context,
                      (
                        postType: _type,
                        title: title,
                        body: _bodyCtrl.text.trim(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(99.dp),
        onTap: onTap,
        child: Ink(
          padding: EdgeInsets.symmetric(horizontal: 12.dp, vertical: 8.dp),
          decoration: BoxDecoration(
            color: selected ? c.accentSoft : c.surface,
            borderRadius: BorderRadius.circular(99.dp),
            border: Border.all(color: selected ? c.accent : c.outline),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? c.accentText : c.textSecondary,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
