import 'package:flutter/material.dart';

import '../profile_avatar.dart';
import '../theme/colors.dart';
import '../../utils/size_controller.dart';

/// Foydalanuvchi qidiruv natijasi: doira avatar + ism + subtitle.
class UserSearchItem extends StatelessWidget {
  final String initial;
  final LinearGradient avatarGradient;
  final String? avatarUrl;
  final String name;
  final String subtitle;
  final bool online;
  final VoidCallback onTap;

  const UserSearchItem({
    super.key,
    required this.initial,
    required this.avatarGradient,
    required this.name,
    required this.subtitle,
    required this.onTap,
    this.avatarUrl,
    this.online = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final radius = BorderRadius.circular(14.dp);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.dp, vertical: 4.dp),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.dp, vertical: 10.dp),
            child: Row(
              children: [
                ProfileAvatar(
                  initial: initial,
                  gradient: avatarGradient,
                  imageUrl: avatarUrl,
                  size: 48,
                  online: online,
                ),
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
                      if (subtitle.trim().isNotEmpty) ...[
                        SizedBox(height: 2.dp),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: c.textFaint, fontSize: 13.sp),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: c.textFaint, size: 22.dp),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
