import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/local/countries_service.dart';
import '../../../domain/models/country_option.dart';
import '../../screens/friends/friend_recommendation.dart';
import '../../utils/size_controller.dart';
import '../theme/colors.dart';

/// Business Match gorizontal kartasi: davlat · headline · % · Chat.
class FriendRecommendationItem extends StatelessWidget {
  final FriendRecommendation item;
  final VoidCallback? onChat;

  const FriendRecommendationItem({
    super.key,
    required this.item,
    this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final radius = BorderRadius.circular(16.dp);
    final countryLabel = _countryLabel(item.country);
    final headline = item.displayHeadline;
    final percent = item.matchPercent.clamp(0, 100);
    final chatRadius = BorderRadius.circular(10.dp);

    return SizedBox(
      width: 172.dp,
      child: Material(
        color: Colors.transparent,
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
                headline,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              if (headline != item.name && item.name.trim().isNotEmpty) ...[
                SizedBox(height: 4.dp),
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textFaint,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const Spacer(),
              Text(
                'ai_rec_match'.trParams({'n': '$percent'}),
                style: TextStyle(
                  color: c.accent,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 10.dp),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onChat,
                  borderRadius: chatRadius,
                  child: Ink(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 9.dp),
                    decoration: BoxDecoration(
                      color: c.accent,
                      borderRadius: chatRadius,
                    ),
                    child: Text(
                      '💬 ${'user_card_action_chat'.tr}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: c.onAccent,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
