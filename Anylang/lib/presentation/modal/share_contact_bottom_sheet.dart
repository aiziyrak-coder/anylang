import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/core/mappers.dart';
import '../../data/local/session_store.dart';
import '../../data/network/friends_repository.dart';
import '../screens/friends/friend.dart';
import '../ui/app_loading.dart';
import '../ui/profile_avatar.dart';
import '../ui/search_field.dart';
import '../ui/theme/colors.dart';
import '../utils/size_controller.dart';

class ShareContactChoice {
  final String name;
  final String phone;
  final int? userId;
  final String? avatarUrl;
  final String? number;

  const ShareContactChoice({
    required this.name,
    required this.phone,
    this.userId,
    this.avatarUrl,
    this.number,
  });
}

/// Do‘stlar (va o‘zingiz) ichidan kontakt tanlash — Telegram uslubi.
Future<ShareContactChoice?> showShareContactBottomSheet(BuildContext context) {
  return showModalBottomSheet<ShareContactChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ShareContactSheet(),
  );
}

class _ShareContactSheet extends StatefulWidget {
  const _ShareContactSheet();

  @override
  State<_ShareContactSheet> createState() => _ShareContactSheetState();
}

class _ShareContactSheetState extends State<_ShareContactSheet> {
  bool _loading = true;
  String? _error;
  List<Friend> _friends = const [];
  String _q = '';

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
    final result = await Get.find<FriendsRepository>().listFriends(limit: 100);
    if (!mounted) return;
    result.when(
      success: (data) {
        final items = asList(data)
            .whereType<Map>()
            .map((e) => Friend.fromApi(Map<String, dynamic>.from(e)))
            .toList();
        setState(() {
          _friends = items;
          _loading = false;
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

  ShareContactChoice _meChoice() {
    final u = SessionStore.user() ?? {};
    final name = (u['full_name']?.toString() ?? '').trim();
    final phone = (u['phone']?.toString() ?? '').trim();
    final number = (u['number']?.toString() ?? '').trim();
    return ShareContactChoice(
      name: name.isEmpty ? 'chat_share_me'.tr : name,
      phone: phone,
      userId: SessionStore.userId(),
      avatarUrl: u['avatar_url']?.toString(),
      number: number.isEmpty ? null : number,
    );
  }

  List<Friend> get _filtered {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return _friends;
    return _friends
        .where(
          (f) =>
              f.name.toLowerCase().contains(q) ||
              (f.number ?? '').contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final h = MediaQuery.sizeOf(context).height * 0.78;
    final me = _meChoice();

    return Container(
      height: h,
      decoration: BoxDecoration(
        color: c.isDark ? const Color(0xFF152A42) : c.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.dp)),
      ),
      padding: EdgeInsets.fromLTRB(16.dp, 12.dp, 16.dp, 12.dp + bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44.dp,
              height: 5.dp,
              decoration: BoxDecoration(
                color: c.outline,
                borderRadius: BorderRadius.circular(5.dp),
              ),
            ),
          ),
          SizedBox(height: 14.dp),
          Text(
            'chat_share_contact_title'.tr,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 4.dp),
          Text(
            'chat_share_contact_hint'.tr,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 12.dp),
          SearchField(
            hint: 'friends_search_hint'.tr,
            onChanged: (v) => setState(() => _q = v),
          ),
          SizedBox(height: 12.dp),
          if (_loading)
            const Expanded(child: AppLoading())
          else if (_error != null)
            Expanded(
              child: Center(
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.textPrimary, fontSize: 14.sp),
                ),
              ),
            )
          else
            Expanded(
              child: ListView(
                children: [
                  _tile(
                    c,
                    name: me.name,
                    subtitle: me.phone.isNotEmpty
                        ? me.phone
                        : (me.number != null ? '#${me.number}' : 'chat_share_me'.tr),
                    initial: initialsOf(me.name),
                    gradient: avatarGradientFor(me.userId ?? 0),
                    avatarUrl: me.avatarUrl,
                    badge: 'chat_share_me'.tr,
                    onTap: () => Navigator.pop(context, me),
                  ),
                  if (_filtered.isNotEmpty) ...[
                    Padding(
                      padding: EdgeInsets.fromLTRB(4.dp, 14.dp, 4.dp, 8.dp),
                      child: Text(
                        'nav_friends'.tr.toUpperCase(),
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    for (final f in _filtered)
                      _tile(
                        c,
                        name: f.name,
                        subtitle: (f.number != null && f.number!.isNotEmpty)
                            ? '#${f.number}'
                            : f.status,
                        initial: f.initial,
                        gradient: f.avatarGradient,
                        avatarUrl: f.avatarUrl,
                        onTap: () => Navigator.pop(
                          context,
                          ShareContactChoice(
                            name: f.name,
                            phone: '',
                            userId: f.id,
                            avatarUrl: f.avatarUrl,
                            number: f.number,
                          ),
                        ),
                      ),
                  ] else
                    Padding(
                      padding: EdgeInsets.only(top: 24.dp),
                      child: Text(
                        'chat_share_no_friends'.tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 13.sp,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _tile(
    AppColors c, {
    required String name,
    required String subtitle,
    required String initial,
    required LinearGradient gradient,
    String? avatarUrl,
    String? badge,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.dp),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 6.dp, vertical: 10.dp),
          child: Row(
            children: [
              ProfileAvatar(
                initial: initial,
                gradient: gradient,
                imageUrl: avatarUrl,
                size: 44,
                shape: ProfileAvatarShape.circle,
              ),
              SizedBox(width: 12.dp),
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
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (badge != null) ...[
                          SizedBox(width: 8.dp),
                          Text(
                            badge,
                            style: TextStyle(
                              color: c.accentText,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 2.dp),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.send_rounded, size: 18.dp, color: c.accentText),
            ],
          ),
        ),
      ),
    );
  }
}
