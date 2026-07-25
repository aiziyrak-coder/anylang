import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../screens/friends/friend_request.dart';
import '../buttons/rich_button.dart';
import '../profile_avatar.dart';
import '../theme/colors.dart';
import '../theme/gradients.dart';
import '../../utils/size_controller.dart';

class FriendRequestItem extends StatelessWidget {
  final FriendRequest request;
  final bool outgoing;
  final bool busy;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onCancel;
  final VoidCallback? onTap;

  const FriendRequestItem({
    super.key,
    required this.request,
    this.outgoing = false,
    this.busy = false,
    this.onAccept,
    this.onDecline,
    this.onCancel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final radius = BorderRadius.circular(14.dp);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          padding: EdgeInsets.all(12.dp),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: radius,
            border: Border.all(color: c.surfaceBorder),
          ),
          child: Row(
            children: [
              ProfileAvatar(
                initial: request.initial,
                gradient: request.avatarGradient,
                imageUrl: request.avatarUrl,
                size: 48,
                online: request.online,
              ),
              SizedBox(width: 12.dp),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (request.subtitle.isNotEmpty) ...[
                      SizedBox(height: 2.dp),
                      Text(
                        request.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.textFaint, fontSize: 12.sp),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 8.dp),
              if (outgoing)
                _outlineBtn(
                  c,
                  'friends_cancel_request'.tr,
                  busy ? null : onCancel,
                )
              else ...[
                _outlineBtn(
                  c,
                  'friends_decline'.tr,
                  busy ? null : onDecline,
                ),
                SizedBox(width: 8.dp),
                RichButton(
                  text: 'friends_accept'.tr,
                  onTap: () {
                    if (busy || onAccept == null) return;
                    onAccept!();
                  },
                  enabled: !busy,
                  textColor: c.onAccent,
                  textStyle: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.dp,
                    vertical: 8.dp,
                  ),
                  borderRadius: BorderRadius.circular(99.dp),
                  decoration: BoxDecoration(
                    gradient: limeButtonGradient,
                    borderRadius: BorderRadius.circular(99.dp),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _outlineBtn(AppColors c, String label, VoidCallback? onTap) {
    final radius = BorderRadius.circular(99.dp);
    return Material(
      color: c.surface,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: c.outline),
          ),
          padding: EdgeInsets.symmetric(horizontal: 12.dp, vertical: 8.dp),
          child: Text(
            label,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
