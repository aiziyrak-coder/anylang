import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../screens/messages/conversation.dart';
import '../ui/items/user_search_item.dart';
import '../ui/search_field.dart';
import '../ui/theme/colors.dart';
import '../utils/size_controller.dart';

/// DM tarixidan guruhga qo'shiladigan nomzodlar.
class GroupMemberCandidate {
  final int userId;
  final String name;
  final String initial;
  final LinearGradient avatarGradient;
  final String? avatarUrl;
  final bool alreadyInGroup;

  const GroupMemberCandidate({
    required this.userId,
    required this.name,
    required this.initial,
    required this.avatarGradient,
    this.avatarUrl,
    this.alreadyInGroup = false,
  });

  factory GroupMemberCandidate.fromConversation(
    Conversation c, {
    required bool alreadyInGroup,
  }) {
    return GroupMemberCandidate(
      userId: c.peerId,
      name: c.name,
      initial: c.initial,
      avatarGradient: c.avatarGradient,
      avatarUrl: c.avatarUrl,
      alreadyInGroup: alreadyInGroup,
    );
  }
}

Future<Set<int>?> showAddGroupMembersBottomSheet(
  BuildContext context, {
  required List<GroupMemberCandidate> candidates,
}) {
  return showModalBottomSheet<Set<int>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AddGroupMembersSheet(candidates: candidates),
  );
}

class _AddGroupMembersSheet extends StatefulWidget {
  final List<GroupMemberCandidate> candidates;

  const _AddGroupMembersSheet({required this.candidates});

  @override
  State<_AddGroupMembersSheet> createState() => _AddGroupMembersSheetState();
}

class _AddGroupMembersSheetState extends State<_AddGroupMembersSheet> {
  final _selected = <int>{};
  String _query = '';

  List<GroupMemberCandidate> get _filtered {
    final q = _query.trim().toLowerCase();
    Iterable<GroupMemberCandidate> list = widget.candidates;
    if (q.isNotEmpty) {
      list = list.where((c) => c.name.toLowerCase().contains(q));
    }
    final sorted = list.toList()
      ..sort((a, b) {
        if (a.alreadyInGroup != b.alreadyInGroup) {
          return a.alreadyInGroup ? -1 : 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final items = _filtered;
    final addable = items.where((e) => !e.alreadyInGroup).toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.dp)),
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.dp, 16.dp, 16.dp, 8.dp),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'group_settings_add_members'.tr,
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _selected.isEmpty
                        ? null
                        : () => Navigator.pop(context, _selected),
                    child: Text('common_add'.tr),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16.dp, 0, 16.dp, 8.dp),
              child: SearchField(
                hint: 'group_add_members_search_hint'.tr,
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            if (addable.isEmpty && _query.isEmpty)
              Padding(
                padding: EdgeInsets.all(24.dp),
                child: Text(
                  'group_settings_no_contacts_to_add'.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.fromLTRB(12.dp, 0, 12.dp, 16.dp),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final item = items[i];
                    if (item.alreadyInGroup) {
                      return Opacity(
                        opacity: 0.55,
                        child: UserSearchItem(
                          initial: item.initial,
                          avatarGradient: item.avatarGradient,
                          avatarUrl: item.avatarUrl,
                          name: item.name,
                          subtitle: 'group_add_members_already_in_group'.tr,
                          onTap: () {},
                        ),
                      );
                    }
                    final on = _selected.contains(item.userId);
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            if (on) {
                              _selected.remove(item.userId);
                            } else {
                              _selected.add(item.userId);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(14.dp),
                        child: Row(
                          children: [
                            Expanded(
                              child: UserSearchItem(
                                initial: item.initial,
                                avatarGradient: item.avatarGradient,
                                avatarUrl: item.avatarUrl,
                                name: item.name,
                                subtitle: 'group_add_members_tap_to_select'.tr,
                                onTap: () {
                                  setState(() {
                                    if (on) {
                                      _selected.remove(item.userId);
                                    } else {
                                      _selected.add(item.userId);
                                    }
                                  });
                                },
                              ),
                            ),
                            Icon(
                              on
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                              color: on ? c.accent : c.textFaint,
                              size: 24.dp,
                            ),
                            SizedBox(width: 8.dp),
                          ],
                        ),
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
}
