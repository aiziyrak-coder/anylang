import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../ui/buttons/my_icon_button.dart';
import '../../ui/theme/colors.dart';
import '../../utils/size_controller.dart';

/// Chat ekrani yuqori paneli — orqaga tugmasi, suhbatdosh avatari (gradient +
/// harf + onlayn nuqtasi), ismi va holati, hamda menyu tugmasi. Faqat shu
/// ekranga xos bo'lgani uchun screen papkasida.
class ChatAppBar extends StatelessWidget {
  final String name;
  final String initial;
  final LinearGradient avatarGradient;
  final bool online;
  final VoidCallback onBack;
  final VoidCallback onMenu;

  const ChatAppBar({
    super.key,
    required this.name,
    required this.initial,
    required this.avatarGradient,
    required this.online,
    required this.onBack,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Container(
      padding: EdgeInsets.fromLTRB(6.dp, 6.dp, 10.dp, 10.dp),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.outline)),
      ),
      child: Row(
        children: [
          MyIconButton(
            onClick: onBack,
            icon: Icons.arrow_back_ios_new,
            iconColor: c.accentText,
            iconSize: 20.dp,
            backgroundColor: Colors.transparent,
            borderRadius: 12.dp,
            padding: EdgeInsets.all(6.dp),
          ),
          SizedBox(width: 2.dp),
          _avatar(c),
          SizedBox(width: 10.dp),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2.dp),
                Text(
                  online ? 'chat_online'.tr : 'chat_offline'.tr,
                  style: TextStyle(color: c.textSecondary, fontSize: 12.sp),
                ),
              ],
            ),
          ),
          MyIconButton(
            onClick: onMenu,
            icon: Icons.more_vert_rounded,
            iconColor: c.textSecondary,
            iconSize: 20.dp,
            backgroundColor: Colors.transparent,
            borderRadius: 12.dp,
            padding: EdgeInsets.all(6.dp),
          ),
        ],
      ),
    );
  }

  Widget _avatar(AppColors c) {
    return SizedBox(
      width: 44.dp,
      height: 44.dp,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44.dp,
            height: 44.dp,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: avatarGradient,
            ),
            child: Text(
              initial,
              style: TextStyle(
                color: kAvatarFg,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (online)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 13.dp,
                height: 13.dp,
                decoration: BoxDecoration(
                  color: kOnline,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.background, width: 2.2.dp),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
