import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../utils/size_controller.dart';
import '../profile_avatar.dart';
import '../theme/colors.dart';
import '../../screens/business_feed/feed_post.dart';
import '../../../data/core/mappers.dart';

/// Business Feed kartasi — Instagram emas: tip badge + matn + ixtiyoriy rasm.
class BusinessFeedItem extends StatelessWidget {
  final FeedPost post;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onDelete;

  const BusinessFeedItem({
    super.key,
    required this.post,
    this.onAuthorTap,
    this.onDelete,
  });

  IconData get _typeIcon => switch (post.postType) {
        'new_product' => Icons.inventory_2_outlined,
        'new_factory' => Icons.precision_manufacturing_outlined,
        'new_certificate' => Icons.workspace_premium_outlined,
        'exhibition' => Icons.storefront_outlined,
        'discount' => Icons.local_offer_outlined,
        _ => Icons.campaign_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final author = post.author;
    final name = author.companyName.isNotEmpty ? author.companyName : '…';
    final initial = initialsOf(name);
    final gradient = avatarGradientFor(author.id);
    final time = _formatTime(post.createdAt);

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18.dp),
        border: Border.all(color: c.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.vertical(top: Radius.circular(18.dp)),
              onTap: onAuthorTap,
              child: Padding(
                padding: EdgeInsets.fromLTRB(14.dp, 12.dp, 8.dp, 10.dp),
                child: Row(
                  children: [
                    ProfileAvatar(
                      initial: initial,
                      gradient: gradient,
                      imageUrl: author.logoUrl,
                      size: 40,
                    ),
                    SizedBox(width: 10.dp),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: c.textPrimary,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (author.factoryVerified || author.verifiedBadge) ...[
                                SizedBox(width: 4.dp),
                                Icon(
                                  Icons.verified_rounded,
                                  size: 16.dp,
                                  color: c.accent,
                                ),
                              ],
                            ],
                          ),
                          if (time.isNotEmpty)
                            Text(
                              time,
                              style: TextStyle(
                                color: c.textFaint,
                                fontSize: 11.sp,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (post.isMine && onDelete != null)
                      IconButton(
                        onPressed: onDelete,
                        icon: Icon(Icons.delete_outline_rounded, color: c.textSecondary),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(14.dp, 0, 14.dp, 12.dp),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.dp, vertical: 5.dp),
                  decoration: BoxDecoration(
                    color: c.accentSoft,
                    borderRadius: BorderRadius.circular(99.dp),
                    border: Border.all(color: c.accent.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_typeIcon, size: 14.dp, color: c.accent),
                      SizedBox(width: 5.dp),
                      Text(
                        feedTypeLabelKey(post.postType).tr,
                        style: TextStyle(
                          color: c.accentText,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10.dp),
                Text(
                  post.title,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                if (post.body.trim().isNotEmpty) ...[
                  SizedBox(height: 6.dp),
                  Text(
                    post.body,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 14.sp,
                      height: 1.45,
                    ),
                  ),
                ],
                if ((post.imageUrl ?? '').isNotEmpty) ...[
                  SizedBox(height: 12.dp),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14.dp),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        post.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => ColoredBox(
                          color: c.background,
                          child: Icon(Icons.broken_image_outlined, color: c.textFaint),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'feed_time_now'.tr;
    if (diff.inMinutes < 60) {
      return 'feed_time_minutes'.trParams({'n': '${diff.inMinutes}'});
    }
    if (diff.inHours < 24) {
      return 'feed_time_hours'.trParams({'n': '${diff.inHours}'});
    }
    if (diff.inDays < 7) {
      return 'feed_time_days'.trParams({'n': '${diff.inDays}'});
    }
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }
}
