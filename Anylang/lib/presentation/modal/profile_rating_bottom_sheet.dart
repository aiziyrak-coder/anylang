import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../ui/theme/colors.dart';
import '../utils/size_controller.dart';

/// Profil reytingi — umumiy ball va sharhlar soni.
Future<void> showProfileRatingBottomSheet(
  BuildContext context, {
  required double? rating,
  required int reviewsCount,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final c = ctx.appColors;
      final hasRating = rating != null && rating > 0;
      final stars = hasRating ? rating.clamp(0.0, 5.0) : 0.0;
      return Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.dp)),
          border: Border(top: BorderSide(color: c.surfaceBorder, width: 0.7)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.dp, 10.dp, 20.dp, 24.dp),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40.dp,
                  height: 4.dp,
                  decoration: BoxDecoration(
                    color: c.outline,
                    borderRadius: BorderRadius.circular(99.dp),
                  ),
                ),
                SizedBox(height: 16.dp),
                Text(
                  'profile_rating_detail_title'.tr,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 20.dp),
                Text(
                  hasRating ? stars.toStringAsFixed(1) : '—',
                  style: TextStyle(
                    color: hasRating ? c.accentText : c.textFaint,
                    fontSize: 42.sp,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                SizedBox(height: 8.dp),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 1; i <= 5; i++)
                      Icon(
                        stars >= i
                            ? Icons.star_rounded
                            : (stars >= i - 0.5
                                ? Icons.star_half_rounded
                                : Icons.star_outline_rounded),
                        color: c.accentText,
                        size: 28.dp,
                      ),
                  ],
                ),
                SizedBox(height: 12.dp),
                Text(
                  reviewsCount > 0
                      ? 'profile_rating_detail_reviews'
                          .trParams({'n': '$reviewsCount'})
                      : 'profile_rating_detail_empty'.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8.dp),
                Text(
                  'profile_rating_detail_hint'.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: c.textFaint,
                    fontSize: 13.sp,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
