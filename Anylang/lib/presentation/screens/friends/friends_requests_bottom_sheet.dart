import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../ui/app_empty_state.dart';
import '../../ui/buttons/rich_button.dart';
import '../../ui/profile_avatar.dart';
import '../../ui/theme/colors.dart';
import '../../ui/theme/gradients.dart';
import '../../utils/size_controller.dart';
import 'friend_request.dart';

/// Kiruvchi do'stlik so'rovlar ro'yxati — Friends sarlavhasidagi badge'dan ochiladi.
Future<void> showFriendsRequestsBottomSheet(
  BuildContext context, {
  required List<FriendRequest> requests,
  required Future<void> Function(int requestId) onAccept,
  required Future<void> Function(int requestId) onDecline,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FriendsRequestsSheet(
      initialRequests: requests,
      onAccept: onAccept,
      onDecline: onDecline,
    ),
  );
}

class _FriendsRequestsSheet extends StatefulWidget {
  final List<FriendRequest> initialRequests;
  final Future<void> Function(int requestId) onAccept;
  final Future<void> Function(int requestId) onDecline;

  const _FriendsRequestsSheet({
    required this.initialRequests,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<_FriendsRequestsSheet> createState() => _FriendsRequestsSheetState();
}

class _FriendsRequestsSheetState extends State<_FriendsRequestsSheet> {
  late List<FriendRequest> _requests = List.of(widget.initialRequests);
  final Set<int> _busy = {};

  Future<void> _handle(
    FriendRequest req,
    Future<void> Function(int requestId) action,
  ) async {
    if (_busy.contains(req.requestId)) return;
    setState(() => _busy.add(req.requestId));
    await action(req.requestId);
    if (!mounted) return;
    setState(() {
      _busy.remove(req.requestId);
      _requests.removeWhere((r) => r.requestId == req.requestId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final maxH = MediaQuery.of(context).size.height * 0.72;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.dp)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 8.dp),
            Container(
              width: 40.dp,
              height: 4.dp,
              decoration: BoxDecoration(
                color: c.textFaint,
                borderRadius: BorderRadius.circular(2.dp),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20.dp, 16.dp, 20.dp, 8.dp),
              child: Text(
                'friends_requests'.tr,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Flexible(
              child: _requests.isEmpty
                  ? AppEmptyState(
                      icon: Icons.inbox_outlined,
                      title: 'friends_no_requests'.tr,
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.fromLTRB(16.dp, 0, 16.dp, 16.dp),
                      itemCount: _requests.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1.dp,
                        color: c.outline,
                      ),
                      itemBuilder: (_, i) {
                        final req = _requests[i];
                        final busy = _busy.contains(req.requestId);
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.dp),
                          child: Row(
                            children: [
                              _avatar(req),
                              SizedBox(width: 12.dp),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      req.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: c.textPrimary,
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (req.subtitle.isNotEmpty) ...[
                                      SizedBox(height: 2.dp),
                                      Text(
                                        req.subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: c.textFaint,
                                          fontSize: 13.sp,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              SizedBox(width: 8.dp),
                              _declineBtn(c, req, busy),
                              SizedBox(width: 8.dp),
                              _acceptBtn(c, req, busy),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(FriendRequest req) {
    return ProfileAvatar(
      initial: req.initial,
      gradient: req.avatarGradient,
      imageUrl: req.avatarUrl,
      size: 48,
      online: req.online,
    );
  }

  Widget _declineBtn(AppColors c, FriendRequest req, bool busy) {
    final radius = BorderRadius.circular(99.dp);
    return Material(
      color: c.surface,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: busy ? null : () => _handle(req, widget.onDecline),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: c.outline),
          ),
          padding: EdgeInsets.symmetric(horizontal: 12.dp, vertical: 8.dp),
          child: Text(
            'friends_decline'.tr,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _acceptBtn(AppColors c, FriendRequest req, bool busy) {
    final radius = BorderRadius.circular(99.dp);
    return RichButton(
      text: 'friends_accept'.tr,
      onTap: () {
        if (busy) return;
        _handle(req, widget.onAccept);
      },
      textColor: c.onAccent,
      textStyle: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
      padding: EdgeInsets.symmetric(horizontal: 12.dp, vertical: 8.dp),
      borderRadius: radius,
      decoration: BoxDecoration(gradient: limeButtonGradient, borderRadius: radius),
    );
  }
}
