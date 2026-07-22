import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/local/countries_service.dart';
import '../../domain/models/country_option.dart';
import '../ui/buttons/primary_button.dart';
import '../ui/items/country_list_item.dart';
import '../ui/search_field.dart';
import '../ui/theme/colors.dart';
import '../utils/size_controller.dart';

/// Davlat tanlash — sheet o‘zi joyida qoladi, faqat ro‘yxat scroll bo‘ladi.
Future<CountryOption?> showCountryPickerBottomSheet(
  BuildContext context, {
  String? title,
  String? desc,
  String? selectedCode,
}) {
  return showModalBottomSheet<CountryOption>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    enableDrag: false,
    builder: (ctx) => _CountryBottomSheet(
      title: title ?? 'country_picker_title'.tr,
      desc: desc ?? 'country_picker_desc'.tr,
      selectedCode: selectedCode?.toUpperCase(),
    ),
  );
}

class _CountryBottomSheet extends StatefulWidget {
  final String title;
  final String desc;
  final String? selectedCode;

  const _CountryBottomSheet({
    required this.title,
    required this.desc,
    this.selectedCode,
  });

  @override
  State<_CountryBottomSheet> createState() => _CountryBottomSheetState();
}

class _CountryBottomSheetState extends State<_CountryBottomSheet> {
  late String? _selectedCode = widget.selectedCode;
  String _query = '';
  List<CountryOption> _all = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = Get.find<CountriesService>();
    final items = await service.getCountries();
    if (!mounted) return;
    setState(() {
      _all = items;
      _loading = false;
      _selectedCode ??= widget.selectedCode;
    });
    await service.refresh(force: false);
    if (!mounted) return;
    final refreshed = service.cached;
    if (refreshed.length != _all.length ||
        refreshed.map((e) => e.code).join() != _all.map((e) => e.code).join()) {
      setState(() => _all = refreshed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final query = _query.trim().toLowerCase();
    final items = _all.where((o) {
      if (query.isEmpty) return true;
      return o.localizedName.toLowerCase().contains(query) ||
          o.nameEn.toLowerCase().contains(query) ||
          o.nameRu.toLowerCase().contains(query) ||
          o.nameUz.toLowerCase().contains(query) ||
          o.code.toLowerCase().contains(query);
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
                          enabled: _selectedCode != null,
                          onTap: () {
                            final code = _selectedCode;
                            if (code == null) return;
                            CountryOption? match;
                            for (final o in _all) {
                              if (o.code == code) {
                                match = o;
                                break;
                              }
                            }
                            Navigator.pop(
                              context,
                              match ??
                                  CountryOption(
                                    code: code,
                                    nameUz: code,
                                    nameRu: code,
                                    nameEn: code,
                                  ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 18.dp),
                  SearchField(
                    hint: 'country_search_hint'.tr,
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  SizedBox(height: 10.dp),
                ],
              ),
            ),
            Flexible(
              child: _loading
                  ? Padding(
                      padding: EdgeInsets.symmetric(vertical: 32.dp),
                      child: const Center(child: CircularProgressIndicator()),
                    )
                  : items.isEmpty
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
                            return CountryListItem(
                              flagEmoji: o.flagEmoji,
                              title: o.localizedName,
                              subtitle: o.code,
                              selected: o.code == _selectedCode,
                              onTap: () =>
                                  setState(() => _selectedCode = o.code),
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
