import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/gradients.dart';
import '../../utils/size_controller.dart';

/// Do'st qo'shish natijasi tugmasining holati.
enum FriendActionState { add, message, requested }

/// "Do'st qo'shish" ro'yxati elementi: avatar + ism + subtitle + holatga qarab
/// tugma (Qo'shish / Yozish / So'rov yuborildi).
class FriendResultItem extends StatelessWidget {
  final String initial;
  final LinearGradient avatarGradient;
  final String name;
  final String subtitle;
  final bool online;
  final FriendActionState action;
  final String actionLabel;
  final VoidCallback onAction;

  const FriendResultItem({
    super.key,
    required this.initial,
    required this.avatarGradient,
    required this.name,
    required this.subtitle,
    required this.online,
    required this.action,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.dp, vertical: 11.dp),
      child: Row(
        children: [
          _avatar(c),
          SizedBox(width: 12.dp),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2.dp),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.textFaint, fontSize: 13.sp),
                ),
              ],
            ),
          ),
          SizedBox(width: 10.dp),
          _actionButton(c),
        ],
      ),
    );
  }

  Widget _avatar(AppColors c) {
    return SizedBox(
      width: 48.dp,
      height: 48.dp,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 48.dp,
            height: 48.dp,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: avatarGradient),
            child: Text(
              initial,
              style: TextStyle(
                color: kAvatarFg,
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (online)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14.dp,
                height: 14.dp,
                decoration: BoxDecoration(
                  color: kOnline,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.background, width: 2.5.dp),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionButton(AppColors c) {
    final radius = BorderRadius.circular(99.dp);
    final bool isAdd = action == FriendActionState.add;
    final bool isRequested = action == FriendActionState.requested;

    // Holatga qarab ko'rinish.
    final Gradient? gradient = isAdd ? limeButtonGradient : null;
    final Color? bg = isAdd
        ? null
        : (action == FriendActionState.message ? c.surface : Colors.transparent);
    // Yozish ham, So'rov yuborildi ham bir xil muted border ishlatadi (figmadagidek).
    final Color borderColor = isAdd ? Colors.transparent : c.outline;
    final Color labelColor = isAdd
        ? c.onAccent
        : (action == FriendActionState.message ? c.textPrimary : c.textFaint);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isRequested ? null : onAction,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            gradient: gradient,
            borderRadius: radius,
            border: isAdd ? null : Border.all(color: borderColor, width: 1.4),
          ),
          padding: EdgeInsets.symmetric(horizontal: 14.dp, vertical: 9.dp),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isAdd) ...[
                Icon(Icons.add, color: labelColor, size: 16.dp),
                SizedBox(width: 3.dp),
              ],
              Text(
                actionLabel,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
