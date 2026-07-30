import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../ui/buttons/my_icon_button.dart';
import '../../ui/frosted_bar.dart';
import '../../ui/profile_avatar.dart';
import '../../ui/theme/colors.dart';
import '../../utils/size_controller.dart';

/// Chat ekrani yuqori paneli — orqaga, suhbatdosh, qidiruv, menyu.
class ChatAppBar extends StatelessWidget {
  final String name;
  final String initial;
  final LinearGradient avatarGradient;
  final String? avatarUrl;
  final bool online;
  /// Agar berilsa — online/offline o‘rniga ko‘rsatiladi (masalan “Yozmoqda...”).
  final String? statusText;
  final bool searching;
  final bool hasSearchQuery;
  final int searchMatchCount;
  final int searchMatchIndex;
  final TextEditingController? searchController;
  final VoidCallback onBack;
  final ValueChanged<Rect> onMenu;
  final VoidCallback onPeerTap;
  final VoidCallback onOpenSearch;
  final VoidCallback onCloseSearch;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearchPrev;
  final VoidCallback? onSearchNext;
  final bool selecting;
  final int selectedCount;
  final VoidCallback? onForwardSelected;
  final VoidCallback? onDeleteSelected;

  const ChatAppBar({
    super.key,
    required this.name,
    required this.initial,
    required this.avatarGradient,
    required this.online,
    this.avatarUrl,
    this.statusText,
    required this.onBack,
    required this.onMenu,
    required this.onPeerTap,
    this.searching = false,
    this.hasSearchQuery = false,
    this.searchMatchCount = 0,
    this.searchMatchIndex = 0,
    this.searchController,
    this.onOpenSearch = _noop,
    this.onCloseSearch = _noop,
    this.onSearchChanged,
    this.onSearchPrev,
    this.onSearchNext,
    this.selecting = false,
    this.selectedCount = 0,
    this.onForwardSelected,
    this.onDeleteSelected,
  });

  static void _noop() {}

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;

    return FrostedBar(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(6.dp, 6.dp, 10.dp, 10.dp),
          child: searching
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _searchRow(c),
                    if (hasSearchQuery) ...[
                      SizedBox(height: 6.dp),
                      _searchNavRow(c),
                    ],
                  ],
                )
              : selecting
                  ? _selectRow(c)
                  : _peerRow(c),
        ),
      ),
    );
  }

  Widget _selectRow(AppColors c) {
    return Row(
      children: [
        MyIconButton(
          onClick: onBack,
          icon: Icons.close_rounded,
          iconColor: c.accentText,
          iconSize: 22.dp,
          backgroundColor: Colors.transparent,
          borderRadius: 12.dp,
          padding: EdgeInsets.all(6.dp),
        ),
        SizedBox(width: 8.dp),
        Expanded(
          child: Text(
            '$selectedCount',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        MyIconButton(
          onClick: onForwardSelected ?? _noop,
          icon: Icons.shortcut_rounded,
          iconColor: c.textPrimary,
          iconSize: 22.dp,
          backgroundColor: Colors.transparent,
          borderRadius: 12.dp,
          padding: EdgeInsets.all(6.dp),
        ),
        MyIconButton(
          onClick: onDeleteSelected ?? _noop,
          icon: Icons.delete_outline_rounded,
          iconColor: const Color(0xFFB42318),
          iconSize: 22.dp,
          backgroundColor: Colors.transparent,
          borderRadius: 12.dp,
          padding: EdgeInsets.all(6.dp),
        ),
      ],
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
                              color: c.isDark
                                  ? const Color(0xFFF4F7FB)
                                  : c.textPrimary,
                              fontSize: 17.sp,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.15,
                            ),
                          ),
                          SizedBox(height: 2.dp),
                          Text(
                            statusText ??
                                (online ? 'chat_online'.tr : 'chat_offline'.tr),
                            style: TextStyle(
                              color: c.isDark
                                  ? const Color(0xCCB8C5D6)
                                  : c.textSecondary,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
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
          onClick: onOpenSearch,
          icon: Icons.search_rounded,
          iconColor: c.textSecondary,
          iconSize: 22.dp,
          backgroundColor: Colors.transparent,
          borderRadius: 12.dp,
          padding: EdgeInsets.all(6.dp),
        ),
        Builder(
          builder: (btnCtx) {
            return MyIconButton(
              onClick: () {
                final box = btnCtx.findRenderObject() as RenderBox?;
                if (box == null || !box.hasSize) {
                  final size = MediaQuery.sizeOf(btnCtx);
                  onMenu(Rect.fromLTWH(size.width - 56, 40, 40, 40));
                  return;
                }
                final offset = box.localToGlobal(Offset.zero);
                onMenu(
                  Rect.fromLTWH(
                    offset.dx,
                    offset.dy,
                    box.size.width,
                    box.size.height,
                  ),
                );
              },
              icon: Icons.more_vert_rounded,
              iconColor: c.textSecondary,
              iconSize: 20.dp,
              backgroundColor: Colors.transparent,
              borderRadius: 12.dp,
              padding: EdgeInsets.all(6.dp),
            );
          },
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
            textInputAction: TextInputAction.search,
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

  Widget _searchNavRow(AppColors c) {
    final total = searchMatchCount;
    final cur = total == 0 ? 0 : (searchMatchIndex + 1);
    final label = total == 0
        ? 'chat_search_empty'.tr
        : 'chat_search_count'.trParams({
            'current': '$cur',
            'total': '$total',
          });
    return Row(
      children: [
        SizedBox(width: 44.dp),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: total == 0 ? c.textFaint : c.textSecondary,
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        MyIconButton(
          onClick: total == 0 ? _noop : (onSearchPrev ?? _noop),
          enabled: total > 0 && searchMatchIndex > 0,
          icon: Icons.keyboard_arrow_up_rounded,
          iconColor: c.textPrimary,
          iconSize: 26.dp,
          backgroundColor: Colors.transparent,
          borderRadius: 12.dp,
          padding: EdgeInsets.all(4.dp),
        ),
        MyIconButton(
          onClick: total == 0 ? _noop : (onSearchNext ?? _noop),
          enabled: total > 0 && searchMatchIndex < total - 1,
          icon: Icons.keyboard_arrow_down_rounded,
          iconColor: c.textPrimary,
          iconSize: 26.dp,
          backgroundColor: Colors.transparent,
          borderRadius: 12.dp,
          padding: EdgeInsets.all(4.dp),
        ),
      ],
    );
  }

  Widget _avatar(AppColors c) {
    return ProfileAvatar(
      initial: initial,
      gradient: avatarGradient,
      imageUrl: avatarUrl,
      size: 44,
      online: online,
    );
  }
}
