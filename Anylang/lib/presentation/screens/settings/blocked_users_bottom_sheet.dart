import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/local/session_store.dart';
import '../../ui/theme/colors.dart';
import '../../utils/size_controller.dart';

/// Bloklangan foydalanuvchilar ro'yxati — pastdan chiqadigan sheet.
Future<void> showBlockedUsersBottomSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _BlockedUsersSheet(parentContext: context),
  );
}

class _BlockedUsersSheet extends StatefulWidget {
  final BuildContext parentContext;

  const _BlockedUsersSheet({required this.parentContext});

  @override
  State<_BlockedUsersSheet> createState() => _BlockedUsersSheetState();
}

class _BlockedUsersSheetState extends State<_BlockedUsersSheet> {
  late List<int> _ids;

  @override
  void initState() {
    super.initState();
    _ids = SessionStore.blockedUserIds();
  }

  Future<void> _unblock(int id) async {
    await SessionStore.setUserBlocked(id, false);
    setState(() => _ids = SessionStore.blockedUserIds());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final maxH = MediaQuery.of(context).size.height * 0.7;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.dp)),
      ),
      padding: EdgeInsets.fromLTRB(
        20.dp,
        12.dp,
        20.dp,
        24.dp + MediaQuery.viewPaddingOf(context).bottom,
      ),
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
          SizedBox(height: 16.dp),
          Text(
            'settings_blocked_users'.tr,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 12.dp),
          if (_ids.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24.dp),
              child: Text(
                'settings_blocked_empty'.tr,
                style: TextStyle(color: c.textFaint, fontSize: 14.sp),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _ids.length,
                separatorBuilder: (_, _) => Divider(height: 1.dp, color: c.outline),
                itemBuilder: (_, i) {
                  final id = _ids[i];
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 10.dp),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'settings_blocked_user'.trParams({'id': '$id'}),
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8.dp),
                            onTap: () => _unblock(id),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.dp,
                                vertical: 6.dp,
                              ),
                              child: Text(
                                'settings_unblock'.tr,
                                style: TextStyle(
                                  color: c.accent,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
