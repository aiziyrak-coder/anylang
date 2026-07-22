import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../ui/app_empty_state.dart';
import '../../ui/buttons/primary_button.dart';
import '../../ui/gradient_background.dart';
import '../../ui/items/language_item.dart';
import '../../ui/search_field.dart';
import '../../ui/theme/colors.dart';
import '../../ui/theme_selector.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import 'select_language_action.dart';
import 'select_language_option.dart';
import 'select_language_state.dart';

class SelectLanguageContent extends ScreenContent<SelectLanguageState> {

  @override
  Widget build(BuildContext context, SelectLanguageState state, void Function(MyAction action) sendAction) {
    final c = context.appColors;

    return GradientBackground(
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.dp, 12.dp, 20.dp, 16.dp),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Brand
              Row(
                children: [
                  Image.asset('assets/images/logo.png', width: 30.dp, height: 30.dp),
                  SizedBox(width: 10.dp),
                  Text(
                    'app_name'.tr,
                    style: TextStyle(color: c.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              SizedBox(height: 22.dp),
              Text(
                'select_language_title'.tr,
                style: TextStyle(color: c.textPrimary, fontSize: 28.sp, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 4.dp),
              Text(
                'select_language_subtitle'.tr,
                style: TextStyle(color: c.textSecondary, fontSize: 14.sp, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 18.dp),
              SearchField(
                hint: 'search_language_hint'.tr,
                onChanged: (v) => sendAction(SearchLang(v)),
              ),
              SizedBox(height: 16.dp),
              Expanded(
                child: Obx(() {
                  final q = state.query.value.trim().toLowerCase();
                  final selected = state.selectedKey.value;
                  final items = languageOptions.where((o) {
                    if (q.isEmpty) return true;
                    return o.nativeName.toLowerCase().contains(q) ||
                        o.key.tr.toLowerCase().contains(q);
                  }).toList();

                  return items.isEmpty
                      ? AppEmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'empty_no_results'.tr,
                        )
                      : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => SizedBox(height: 12.dp),
                    itemBuilder: (_, i) {
                      final o = items[i];
                      return LanguageItem(
                        flagAsset: o.flag,
                        nativeName: o.nativeName,
                        localizedName: o.key.tr,
                        selected: o.key == selected,
                        onTap: () => sendAction(SelectLang(o.key, o.localeCode, o.langCode)),
                      );
                    },
                  );
                }),
              ),
              SizedBox(height: 16.dp),
              Text(
                'appearance'.tr,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 12.dp),
              ThemeSelector(onSelect: (m) => sendAction(ChangeThemeMode(m))),
              SizedBox(height: 16.dp),
              PrimaryButton(
                text: 'continue'.tr,
                onTap: () => sendAction(Continue()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
