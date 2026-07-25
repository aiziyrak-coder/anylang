import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../ui/theme/colors.dart';
import '../../utils/size_controller.dart';
import 'profile_insights.dart';

/// Yutuqlar — tarjima, tillar, e’lon, reyting.
class ProfileAchievementsSection extends StatelessWidget {
  final ProfileAchievements achievements;

  const ProfileAchievementsSection({super.key, required this.achievements});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final items = [
      _Item(
        icon: Icons.emoji_events_rounded,
        title: 'profile_ach_translations'.tr,
        unlocked: achievements.translations100,
      ),
      _Item(
        icon: Icons.public_rounded,
        title: 'profile_ach_languages'.tr,
        unlocked: achievements.languages10,
      ),
      _Item(
        icon: Icons.inventory_2_outlined,
        title: 'profile_ach_first_listing'.tr,
        unlocked: achievements.firstListing,
      ),
      _Item(
        icon: Icons.star_rounded,
        title: 'profile_ach_rating'.tr,
        unlocked: achievements.rating5,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'profile_achievements_title'.tr.toUpperCase(),
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 12.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
        SizedBox(height: 10.dp),
        Wrap(
          spacing: 10.dp,
          runSpacing: 10.dp,
          children: [
            for (final item in items)
              SizedBox(
                width: (MediaQuery.sizeOf(context).width - 50.dp) / 2,
                child: _chip(c, item),
              ),
          ],
        ),
      ],
    );
  }

  Widget _chip(AppColors c, _Item item) {
    final bg = item.unlocked
        ? c.accentSoft
        : (c.isDark ? const Color(0x55152A42) : const Color(0xCCFFFFFF));
    final fg = item.unlocked ? c.accentText : c.textFaint;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.dp, vertical: 12.dp),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16.dp),
        border: Border.all(
          color: item.unlocked ? c.accent.withValues(alpha: 0.45) : c.surfaceBorder,
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Icon(item.icon, size: 20.dp, color: fg),
          SizedBox(width: 8.dp),
          Expanded(
            child: Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: item.unlocked ? c.textPrimary : c.textSecondary,
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
          if (item.unlocked)
            Icon(Icons.check_circle_rounded, size: 16.dp, color: c.accentText),
        ],
      ),
    );
  }
}

class _Item {
  final IconData icon;
  final String title;
  final bool unlocked;

  const _Item({
    required this.icon,
    required this.title,
    required this.unlocked,
  });
}
