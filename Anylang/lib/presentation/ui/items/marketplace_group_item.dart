import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../screens/marketplace_groups/marketplace_group.dart';
import '../theme/colors.dart';
import '../../utils/size_controller.dart';

class MarketplaceGroupItem extends StatelessWidget {
  final MarketplaceGroup group;
  final VoidCallback onTap;

  const MarketplaceGroupItem({
    super.key,
    required this.group,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final blurbKey = 'marketplace_group_blurb_${group.slug}';
    final blurb = blurbKey.tr == blurbKey ? group.blurb : blurbKey.tr;
    final titleKey = 'marketplace_group_title_${group.slug}';
    final title = titleKey.tr == titleKey ? group.title : titleKey.tr;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.dp),
        child: Ink(
          padding: EdgeInsets.all(14.dp),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16.dp),
            border: Border.all(
              color: group.verifiedOnly ? c.accent.withValues(alpha: 0.45) : c.surfaceBorder,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48.dp,
                height: 48.dp,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.accentSoft,
                  borderRadius: BorderRadius.circular(14.dp),
                ),
                child: Text(group.emoji, style: TextStyle(fontSize: 22.sp)),
              ),
              SizedBox(width: 12.dp),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (group.verifiedOnly)
                          Container(
                            margin: EdgeInsets.only(right: group.joined ? 6.dp : 0),
                            padding: EdgeInsets.symmetric(
                              horizontal: 7.dp,
                              vertical: 3.dp,
                            ),
                            decoration: BoxDecoration(
                              color: c.accentSoft,
                              borderRadius: BorderRadius.circular(8.dp),
                            ),
                            child: Text(
                              '✔ ${'marketplace_verified_badge'.tr}',
                              style: TextStyle(
                                color: c.accent,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        if (group.joined)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.dp,
                              vertical: 3.dp,
                            ),
                            decoration: BoxDecoration(
                              color: c.accentSoft,
                              borderRadius: BorderRadius.circular(8.dp),
                            ),
                            child: Text(
                              'marketplace_joined'.tr,
                              style: TextStyle(
                                color: c.accent,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 4.dp),
                    Text(
                      blurb,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 12.sp,
                        height: 1.35,
                      ),
                    ),
                    SizedBox(height: 8.dp),
                    Text(
                      'marketplace_group_meta'.trParams({
                        'members': '${group.memberCount}',
                        'rfq': '${group.rfqToday}',
                      }),
                      style: TextStyle(
                        color: c.textFaint,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (group.verifiedOnly && !group.joined && !group.canJoin) ...[
                      SizedBox(height: 6.dp),
                      Text(
                        'marketplace_verified_locked'.tr,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 4.dp),
              Icon(
                group.verifiedOnly && !group.joined && !group.canJoin
                    ? Icons.lock_outline_rounded
                    : Icons.chevron_right_rounded,
                color: c.textFaint,
                size: 22.dp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
