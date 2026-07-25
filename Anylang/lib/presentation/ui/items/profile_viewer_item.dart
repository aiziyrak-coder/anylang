import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/local/countries_service.dart';
import '../../../domain/models/country_option.dart';
import '../../screens/friends/profile_viewer.dart';
import '../../utils/size_controller.dart';
import '../theme/colors.dart';

/// «Kim sizni qidirdi» gorizontal kartasi.
class ProfileViewerItem extends StatelessWidget {
  final ProfileViewer item;
  final VoidCallback? onTap;

  const ProfileViewerItem({
    super.key,
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final radius = BorderRadius.circular(16.dp);
    final countryLabel = _countryLabel(item.country);

    return SizedBox(
      width: 168.dp,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Ink(
            padding: EdgeInsets.all(14.dp),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: radius,
              border: Border.all(color: c.surfaceBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  countryLabel ?? '🌍',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8.dp),
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const Spacer(),
                Text(
                  'profile_viewers_saw'.tr,
                  style: TextStyle(
                    color: c.textFaint,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _countryLabel(String? code) {
    final raw = (code ?? '').trim().toUpperCase();
    if (raw.isEmpty) return null;
    try {
      if (Get.isRegistered<CountriesService>()) {
        final match = Get.find<CountriesService>().findByCode(raw);
        if (match != null) {
          final flag = match.flagEmoji.trim();
          final name = match.localizedName.trim();
          if (flag.isNotEmpty && name.isNotEmpty) return '$flag $name';
          if (name.isNotEmpty) return name;
        }
      }
      for (final o in kFallbackCountries) {
        if (o.code.toUpperCase() == raw) {
          final flag = o.flagEmoji.trim();
          final name = o.localizedName.trim();
          if (flag.isNotEmpty && name.isNotEmpty) return '$flag $name';
          if (name.isNotEmpty) return name;
        }
      }
    } catch (_) {}
    return raw;
  }
}
