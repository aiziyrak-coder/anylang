import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../utils/size_controller.dart';
import 'theme/colors.dart';

/// Joriy form uslubidagi (FieldBox: kulrang fon, ustki binafsha label) dropdown.
/// Label va tanlangan qiymat bitta kulrang quti ichida ko'rinadi.
class CustomDropDownMenu<T> extends StatelessWidget {
  final String label;
  final String hintText;
  final bool showSearch;
  final List<T> items;
  final T? initialItem;
  final Function(T) selectedItem;

  const CustomDropDownMenu({
    super.key,
    required this.label,
    this.showSearch = false,
    this.hintText = '',
    this.initialItem,
    required this.items,
    required this.selectedItem,
  });

  CustomDropdownDecoration get _decoration => CustomDropdownDecoration(
        closedFillColor: fieldFill,
        expandedFillColor: Colors.white,
        closedBorder: Border.all(color: Colors.transparent),
        closedBorderRadius: BorderRadius.circular(16.dp),
        expandedBorder: Border.all(color: bluePrimary),
        expandedBorderRadius: BorderRadius.circular(16.dp),
        closedSuffixIcon: Icon(Icons.keyboard_arrow_down_rounded, color: notActiveText, size: 20.dp),
        expandedSuffixIcon: Icon(Icons.keyboard_arrow_up_rounded, color: bluePrimary, size: 20.dp),
        listItemStyle: TextStyle(
          fontFamily: 'Fustat',
          fontSize: 15.sp,
          fontWeight: FontWeight.w500,
          color: textDark,
        ),
      );

  EdgeInsets get _padding => EdgeInsets.symmetric(horizontal: 16.dp, vertical: 11.dp);

  Widget _closed(String value, {required bool isHint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w500,
            color: fieldLabel,
            letterSpacing: 0.2,
          ),
        ),
        SizedBox(height: 4.dp),
        Text(
          value.isEmpty ? 'select'.tr : value,
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w500,
            color: isHint ? notActiveText : textDark,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (showSearch) {
      return CustomDropdown<T>.search(
        items: items,
        initialItem: initialItem,
        hintText: hintText,
        searchHintText: '${'search'.tr} :',
        closedHeaderPadding: _padding,
        decoration: _decoration,
        headerBuilder: (_, item, __) => _closed(item.toString(), isHint: false),
        hintBuilder: (_, hint, __) => _closed(hint, isHint: true),
        onChanged: (value) {
          if (value != null) selectedItem(value);
        },
      );
    }

    return CustomDropdown<T>(
      items: items,
      initialItem: initialItem,
      hintText: hintText,
      closedHeaderPadding: _padding,
      decoration: _decoration,
      headerBuilder: (_, item, __) => _closed(item.toString(), isHint: false),
      hintBuilder: (_, hint, __) => _closed(hint, isHint: true),
      onChanged: (value) {
        if (value != null) selectedItem(value);
      },
    );
  }
}
