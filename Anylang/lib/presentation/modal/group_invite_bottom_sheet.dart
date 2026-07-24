import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/core/mappers.dart';
import '../../data/network/chat_repository.dart';
import '../../data/network/invite_deep_link_service.dart';
import '../ui/buttons/primary_button.dart';
import '../ui/profile_avatar.dart';
import '../ui/theme/colors.dart';
import '../utils/app_snackbar.dart';
import '../utils/size_controller.dart';

/// Telegram uslubi: guruh preview + pastda Qo‘shilish / Ochish.
Future<void> showGroupInviteBottomSheet(
  BuildContext context, {
  required String token,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _GroupInviteSheet(token: token),
  );
}

class _GroupInviteSheet extends StatefulWidget {
  final String token;

  const _GroupInviteSheet({required this.token});

  @override
  State<_GroupInviteSheet> createState() => _GroupInviteSheetState();
}

class _GroupInviteSheetState extends State<_GroupInviteSheet> {
  bool _loading = true;
  bool _joining = false;
  String? _error;
  String _title = '';
  String? _avatarUrl;
  int _members = 0;
  bool _isMember = false;
  bool _isSuper = false;
  int? _chatId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await Get.find<ChatRepository>().previewInvite(widget.token);
    if (!mounted) return;
    result.when(
      success: (data) {
        final map = asMap(data) ?? {};
        setState(() {
          _loading = false;
          _title = (map['title']?.toString().trim().isNotEmpty == true)
              ? map['title'].toString()
              : 'Guruh';
          _avatarUrl = map['avatar_url']?.toString();
          _members = (map['member_count'] as num?)?.toInt() ?? 0;
          _isMember = map['is_member'] == true;
          _isSuper = map['is_super'] == true;
          _chatId = (map['chat_id'] as num?)?.toInt();
        });
      },
      failure: (err) {
        setState(() {
          _loading = false;
          _error = '$err';
        });
      },
    );
  }

  Future<void> _primary() async {
    if (_joining) return;
    setState(() => _joining = true);

    final token = widget.token;
    final title = _title;
    final avatar = _avatarUrl;
    final isSuper = _isSuper;
    final service = Get.find<InviteDeepLinkService>();
    final nav = Navigator.of(context);

    if (_isMember) {
      final chatId = _chatId;
      nav.pop();
      if (chatId != null && chatId > 0) {
        await service.joinAndOpen(
          token,
          alreadyMemberChatId: chatId,
          titleHint: title,
          avatarHint: avatar,
          isSuperHint: isSuper,
        );
      }
      return;
    }

    final result = await Get.find<ChatRepository>().joinByToken(token);
    if (!mounted) return;

    int chatId = 0;
    String? joinTitle = title;
    String? joinAvatar = avatar;
    var joinSuper = isSuper;
    String? err;
    result.when(
      success: (data) {
        final map = asMap(data) ?? {};
        chatId = (map['id'] as num?)?.toInt() ?? 0;
        final t = map['title']?.toString();
        if (t != null && t.trim().isNotEmpty) joinTitle = t;
        joinAvatar = map['avatar_url']?.toString() ?? joinAvatar;
        joinSuper = map['is_super'] == true || joinSuper;
      },
      failure: (e) => err = '$e',
    );

    if (err != null || chatId <= 0) {
      setState(() => _joining = false);
      if (err != null && err!.isNotEmpty) showAppError(err);
      return;
    }

    nav.pop();
    await service.joinAndOpen(
      token,
      alreadyMemberChatId: chatId,
      titleHint: joinTitle,
      avatarHint: joinAvatar,
      isSuperHint: joinSuper,
    );
    showAppMessage('group_join_ok'.tr);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final bottom = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: c.isDark ? const Color(0xFF152A42) : c.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.dp)),
      ),
      padding: EdgeInsets.fromLTRB(20.dp, 12.dp, 20.dp, 16.dp + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44.dp,
            height: 5.dp,
            decoration: BoxDecoration(
              color: c.outline,
              borderRadius: BorderRadius.circular(5.dp),
            ),
          ),
          SizedBox(height: 18.dp),
          if (_loading)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 28.dp),
              child: CircularProgressIndicator(color: c.accent),
            )
          else if (_error != null) ...[
            Icon(Icons.link_off_rounded, size: 40.dp, color: kListenRed),
            SizedBox(height: 12.dp),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 16.dp),
            PrimaryButton(text: 'common_retry'.tr, onTap: _load),
          ] else ...[
            ProfileAvatar(
              initial: _title.isNotEmpty ? _title[0].toUpperCase() : 'G',
              gradient: avatarGradientFor(_title.hashCode),
              imageUrl: _avatarUrl,
              size: 72,
              shape: ProfileAvatarShape.circle,
            ),
            SizedBox(height: 14.dp),
            Text(
              _title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 20.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (_isSuper) ...[
              SizedBox(height: 6.dp),
              Text(
                'group_settings_super_badge'.tr,
                style: TextStyle(
                  color: c.accentText,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            SizedBox(height: 6.dp),
            Text(
              'group_invite_members'.trParams({'count': '$_members'}),
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 22.dp),
            PrimaryButton(
              text: _isMember ? 'group_open_button'.tr : 'group_join_button'.tr,
              isLoading: _joining,
              onTap: _primary,
              startIcon: Icon(
                _isMember ? Icons.chat_rounded : Icons.group_add_rounded,
                size: 18.dp,
                color: c.onAccent,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
