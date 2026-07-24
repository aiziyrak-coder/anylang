import 'package:flutter/material.dart';
import '../profile_avatar.dart';
import '../theme/colors.dart';
import '../../utils/size_controller.dart';

/// Suhbatlar / do‘stlar ro'yxati elementi: doira avatar (rasm yoki harf).
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
  final bool pinned;
  final bool isGroup;
  final String? avatarUrl;
  final VoidCallback onTap;
  final ValueChanged<Rect>? onLongPress;
  final bool selected;

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
    this.pinned = false,
    this.isGroup = false,
    this.avatarUrl,
    required this.onTap,
    this.onLongPress,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final radius = BorderRadius.circular(16.dp);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress == null
            ? null
            : () {
                final box = context.findRenderObject() as RenderBox?;
                if (box == null || !box.hasSize) return;
                final offset = box.localToGlobal(Offset.zero);
                onLongPress!(
                  Rect.fromLTWH(offset.dx, offset.dy, box.size.width, box.size.height),
                );
              },
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            color: selected
                ? c.accentSoft
                : (highlighted ? c.accentSoft : Colors.transparent),
            borderRadius: radius,
            border: selected
                ? Border.all(color: c.accent.withValues(alpha: 0.45))
                : null,
          ),
          padding: EdgeInsets.symmetric(horizontal: 11.dp, vertical: 11.dp),
          child: Row(
            children: [
              ProfileAvatar(
                initial: initial,
                gradient: avatarGradient,
                imageUrl: avatarUrl,
                size: 52,
                online: online,
              ),
              SizedBox(width: 12.dp),
              Expanded(child: _content(c)),
              if (selected)
                Icon(Icons.check_circle, color: c.accent, size: 22.dp),
            ],
          ),
        ),
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
            if (isGroup) ...[
              Icon(Icons.groups_rounded, color: c.textFaint, size: 14.dp),
              SizedBox(width: 4.dp),
            ],
            if (pinned) ...[
              Icon(Icons.push_pin_rounded, color: c.textFaint, size: 14.dp),
              SizedBox(width: 4.dp),
            ],
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
