import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../../utils/size_controller.dart';

/// Suhbatlar ro'yxatining bitta elementi: avatar (gradient + harf + onlayn
/// nuqtasi) + ism + oxirgi xabar + vaqt + o'qilmagan belgisi.
class ConversationItem extends StatelessWidget {
  final String initial;
  final LinearGradient avatarGradient;
  final Color initialColor;
  final String name;
  final String lastMessage;
  final String time;
  final bool online;
  final int unread;
  final bool highlighted;
  final bool muted;
  final VoidCallback onTap;

  const ConversationItem({
    super.key,
    required this.initial,
    required this.avatarGradient,
    required this.initialColor,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.online,
    required this.unread,
    required this.highlighted,
    this.muted = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final radius = BorderRadius.circular(16.dp);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            color: highlighted ? c.accentSoft : Colors.transparent,
            borderRadius: radius,
          ),
          padding: EdgeInsets.symmetric(horizontal: 11.dp, vertical: 11.dp),
          child: Row(
            children: [
              _avatar(c),
              SizedBox(width: 12.dp),
              Expanded(child: _content(c)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatar(AppColors c) {
    return SizedBox(
      width: 52.dp,
      height: 52.dp,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 52.dp,
            height: 52.dp,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: avatarGradient,
            ),
            child: Text(
              initial,
              style: TextStyle(
                color: initialColor,
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (online)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 15.dp,
                height: 15.dp,
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

  Widget _content(AppColors c) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(width: 8.dp),
            if (muted) ...[
              Icon(Icons.notifications_off_outlined, color: c.textFaint, size: 14.dp),
              SizedBox(width: 4.dp),
            ],
            Text(
              time,
              style: TextStyle(color: c.textFaint, fontSize: 12.sp),
            ),
          ],
        ),
        SizedBox(height: 4.dp),
        Row(
          children: [
            Expanded(
              child: Text(
                lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: highlighted ? c.textSecondary : c.textFaint,
                  fontSize: 14.sp,
                ),
              ),
            ),
            if (unread > 0) ...[
              SizedBox(width: 8.dp),
              _unreadBadge(c),
            ],
          ],
        ),
      ],
    );
  }

  Widget _unreadBadge(AppColors c) {
    return Container(
      constraints: BoxConstraints(minWidth: 20.dp),
      padding: EdgeInsets.symmetric(horizontal: 7.dp, vertical: 2.dp),
      decoration: BoxDecoration(
        color: c.accent,
        borderRadius: BorderRadius.circular(10.dp),
      ),
      alignment: Alignment.center,
      child: Text(
        unread > 99 ? '99+' : '$unread',
        style: TextStyle(
          color: c.onAccent,
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
