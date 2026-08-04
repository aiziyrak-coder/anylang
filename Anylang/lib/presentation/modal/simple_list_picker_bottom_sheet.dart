import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../ui/theme/colors.dart';
import '../utils/size_controller.dart';

/// Umumiy bitta ustunli ro'yxatdan tanlash — pastdan chiqadigan sheet.
/// Ko‘p element bo‘lsa qidiruv maydoni chiqadi.
Future<String?> showSimpleListPickerBottomSheet(
  BuildContext context, {
  required String title,
  required List<String> items,
  String? selected,
  bool searchable = false,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return _SimpleListPickerSheet(
        title: title,
        items: items,
        selected: selected,
        searchable: searchable || items.length > 12,
      );
    },
  );
}

class _SimpleListPickerSheet extends StatefulWidget {
  final String title;
  final List<String> items;
  final String? selected;
  final bool searchable;

  const _SimpleListPickerSheet({
    required this.title,
    required this.items,
    required this.searchable,
    this.selected,
  });

  @override
  State<_SimpleListPickerSheet> createState() => _SimpleListPickerSheetState();
}

class _SimpleListPickerSheetState extends State<_SimpleListPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.items
        : widget.items
            .where((e) => e.toLowerCase().contains(q))
            .toList(growable: false);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: c.isDark ? const Color(0xFF0C2136) : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.dp)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.dp, 12.dp, 20.dp, 24.dp),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44.dp,
                height: 5.dp,
                decoration: BoxDecoration(
                  color: c.outline,
                  borderRadius: BorderRadius.circular(5.dp),
                ),
              ),
              SizedBox(height: 16.dp),
              Text(
                widget.title,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (widget.searchable) ...[
                SizedBox(height: 12.dp),
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  style: TextStyle(color: c.textPrimary, fontSize: 15.sp),
                  decoration: InputDecoration(
                    hintText: 'common_search'.tr,
                    hintStyle: TextStyle(color: c.textFaint),
                    prefixIcon: Icon(Icons.search_rounded, color: c.textFaint),
                    filled: true,
                    fillColor: c.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.dp),
                      borderSide: BorderSide(color: c.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.dp),
                      borderSide: BorderSide(color: c.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.dp),
                      borderSide: BorderSide(color: c.accent),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12.dp,
                      vertical: 10.dp,
                    ),
                  ),
                ),
              ],
              SizedBox(height: 12.dp),
              Flexible(
                child: filtered.isEmpty
                    ? Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.dp),
                        child: Text(
                          'common_no_results'.tr,
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 14.sp,
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final name = filtered[i];
                          final isSelected = name == widget.selected;
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => Navigator.pop(context, name),
                              borderRadius: BorderRadius.circular(12.dp),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: 14.dp,
                                  horizontal: 8.dp,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: TextStyle(
                                          color: isSelected
                                              ? c.accent
                                              : c.textPrimary,
                                          fontSize: 15.sp,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(
                                        Icons.check_rounded,
                                        color: c.accent,
                                        size: 20.dp,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
