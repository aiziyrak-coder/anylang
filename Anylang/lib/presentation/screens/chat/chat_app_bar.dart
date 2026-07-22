import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../ui/buttons/my_icon_button.dart';
import '../../ui/theme/colors.dart';
import '../../utils/size_controller.dart';

/// Chat ekrani yuqori paneli — orqaga tugmasi, suhbatdosh avatari (gradient +
/// harf + onlayn nuqtasi), ismi va holati, hamda menyu tugmasi. Qidiruv
/// rejimida app bar o‘rniga qidiruv maydoni chiqadi.
class ChatAppBar extends StatelessWidget {
  final String name;
  final String initial;
  final LinearGradient avatarGradient;
  final bool online;
  final bool searching;
  final bool hasSearchQuery;
  final TextEditingController? searchController;
  final VoidCallback onBack;
  final VoidCallback onMenu;
  final VoidCallback onPeerTap;
  final VoidCallback onCloseSearch;
  final ValueChanged<String>? onSearchChanged;

  const ChatAppBar({
    super.key,
    required this.name,
    required this.initial,
    required this.avatarGradient,
    required this.online,
    required this.onBack,
    required this.onMenu,
    required this.onPeerTap,
    this.searching = false,
    this.hasSearchQuery = false,
    this.searchController,
    this.onCloseSearch = _noop,
    this.onSearchChanged,
  });

  static void _noop() {}

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return Container(
      padding: EdgeInsets.fromLTRB(6.dp, 6.dp, 10.dp, 10.dp),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.outline)),
      ),
      child: searching ? _searchRow(c) : _peerRow(c),
    );
  }

  Widget _peerRow(AppColors c) {
    return Row(
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
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPeerTap,
              borderRadius: BorderRadius.circular(12.dp),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 2.dp, horizontal: 2.dp),
                child: Row(
                  children: [
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
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 12.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
    );
  }

  Widget _searchRow(AppColors c) {
    return Row(
      children: [
        MyIconButton(
          onClick: onCloseSearch,
          icon: Icons.arrow_back_ios_new,
          iconColor: c.accentText,
          iconSize: 20.dp,
          backgroundColor: Colors.transparent,
          borderRadius: 12.dp,
          padding: EdgeInsets.all(6.dp),
        ),
        Expanded(
          child: TextField(
            controller: searchController,
            autofocus: true,
            onChanged: onSearchChanged,
            style: TextStyle(color: c.textPrimary, fontSize: 16.sp),
            cursorColor: c.accentText,
            decoration: InputDecoration(
              hintText: 'chat_search_hint'.tr,
              hintStyle: TextStyle(color: c.textSecondary, fontSize: 15.sp),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 10.dp),
            ),
          ),
        ),
        if (hasSearchQuery)
          MyIconButton(
            onClick: () {
              searchController?.clear();
              onSearchChanged?.call('');
            },
            icon: Icons.close_rounded,
            iconColor: c.textSecondary,
            iconSize: 20.dp,
            backgroundColor: Colors.transparent,
            borderRadius: 12.dp,
            padding: EdgeInsets.all(6.dp),
          ),
      ],
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
