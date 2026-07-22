import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../screens/select_language/select_language_option.dart';
import '../ui/buttons/primary_button.dart';
import '../ui/items/language_item.dart';
import '../ui/search_field.dart';
import '../ui/theme/colors.dart';
import '../utils/size_controller.dart';

/// Til tanlash — sheet joyida, faqat ro‘yxat scroll.
Future<LanguageOption?> showLanguageBottomSheet(
  BuildContext context, {
  required String title,
  required String desc,
  String? selectedKey,
}) {
  return showModalBottomSheet<LanguageOption>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    enableDrag: false,
    builder: (ctx) => _LanguageBottomSheet(
      title: title,
      desc: desc,
      selectedKey: selectedKey,
    ),
  );
}

class _LanguageBottomSheet extends StatefulWidget {
  final String title;
  final String desc;
  final String? selectedKey;

  const _LanguageBottomSheet({
    required this.title,
    required this.desc,
    this.selectedKey,
  });

  @override
  State<_LanguageBottomSheet> createState() => _LanguageBottomSheetState();
}

class _LanguageBottomSheetState extends State<_LanguageBottomSheet> {
  late String? _selectedKey = widget.selectedKey;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final query = _query.trim().toLowerCase();
    final items = languageOptions.where((o) {
      if (query.isEmpty) return true;
      return o.nativeName.toLowerCase().contains(query) ||
          o.key.tr.toLowerCase().contains(query);
    }).toList();

    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    final viewPad = MediaQuery.viewPaddingOf(context).bottom;
    final maxH = MediaQuery.sizeOf(context).height * 0.86;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxH),
        decoration: BoxDecoration(
          gradient: c.backgroundGradient,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.dp)),
          border: Border(top: BorderSide(color: c.outline)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20.dp, 12.dp, 20.dp, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40.dp,
                      height: 4.dp,
                      decoration: BoxDecoration(
                        color: c.outline,
                        borderRadius: BorderRadius.circular(2.dp),
                      ),
                    ),
                  ),
                  SizedBox(height: 18.dp),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 20.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 6.dp),
                            Text(
                              widget.desc,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: c.textSecondary,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12.dp),
                      IntrinsicWidth(
                        child: PrimaryButton(
                          text: 'select_language_confirm'.tr,
                          enabled: _selectedKey != null,
                          onTap: () {
                            final key = _selectedKey;
                            if (key == null) return;
                            Navigator.pop(
                              context,
                              languageOptions.firstWhere((o) => o.key == key),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 18.dp),
                  SearchField(
                    hint: 'search_language_hint'.tr,
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  SizedBox(height: 10.dp),
                ],
              ),
            ),
            Flexible(
              child: items.isEmpty
                  ? Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.dp),
                      child: Text(
                        'empty_no_results'.tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 14.sp,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        20.dp,
                        4.dp,
                        20.dp,
                        20.dp + viewPad,
                      ),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => SizedBox(height: 10.dp),
                      itemBuilder: (_, i) {
                        final o = items[i];
                        return LanguageItem(
                          flagAsset: o.flag,
                          nativeName: o.nativeName,
                          localizedName: o.key.tr,
                          selected: o.key == _selectedKey,
                          onTap: () => setState(() => _selectedKey = o.key),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
