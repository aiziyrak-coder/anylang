import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/core/mappers.dart';
import '../../../data/network/chat_repository.dart';
import '../../../data/network/friends_repository.dart';
import '../../../data/network/payment_repository.dart';
import '../../modal/image_picker.dart';
import '../../modal/telegram_action_sheet.dart';
import '../../ui/theme/colors.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../../utils/size_controller.dart';
import '../friends/friend.dart';
import 'group_settings_action.dart';
import 'group_settings_content.dart';
import 'group_settings_payload.dart';
import 'group_settings_state.dart';

class GroupSettingsScreen extends Screen<GroupSettingsState, GroupSettingsPayload> {
  GroupSettingsScreen() : super(mobileContent: GroupSettingsContent());

  @override
  void initState(GroupSettingsPayload? payload) {
    final p = payload;
    if (p == null) return;
    state.chatId = p.chatId;
    state.title.value = p.title;
    state.avatarUrl.value = p.avatarUrl;
    state.myRole.value = p.myRole;
    state.isSuper.value = p.isSuper;
    state.inviteLink.value = p.inviteLink;
    state.memberLimit.value = p.memberLimit;
    Future.microtask(() => sendAction(ReloadMembers()));
  }

  bool get _isAdmin {
    final r = state.myRole.value;
    return r == 'owner' || r == 'admin';
  }

  bool get _isOwner => state.myRole.value == 'owner';

  @override
  Future<void> actionHandler(GroupSettingsState state, MyAction action) async {
    final repo = Get.find<ChatRepository>();
    switch (action) {
      case Back _:
        popBackNavigate();

      case ReloadMembers _:
        state.loading.value = true;
        final result = await repo.listMembers(state.chatId);
        result.when(
          success: (data) {
            final map = asMap(data) ?? {};
            final items = (map['items'] as List?) ?? const [];
            state.members.assignAll(
              items
                  .whereType<Map>()
                  .map((e) => GroupMemberVm.fromApi(Map<String, dynamic>.from(e))),
            );
            repo.getInvite(state.chatId).then((inv) {
              inv.when(
                success: (d) {
                  final m = asMap(d) ?? {};
                  state.inviteLink.value = m['link']?.toString();
                },
                failure: (_) {},
              );
            });
          },
          failure: showAppError,
        );
        state.loading.value = false;

      case AddGroupMembers _:
        await _addMembers();
        break;

      case SaveGroupTitle a:
        if (!_isAdmin) return;
        final title = a.title.trim();
        if (title.isEmpty) return;
        state.saving.value = true;
        final result = await repo.updateGroup(chatId: state.chatId, title: title);
        result.when(
          success: (_) {
            state.title.value = title;
            _toast('group_settings_saved'.tr);
          },
          failure: showAppError,
        );
        state.saving.value = false;

      case PickGroupAvatar _:
        if (!_isAdmin) return;
        final file = await pickImage(context, source: ImageSource.gallery);
        if (file == null) return;
        state.saving.value = true;
        final result = await repo.uploadGroupAvatar(state.chatId, file.path);
        result.when(
          success: (data) {
            final m = asMap(data) ?? {};
            state.avatarUrl.value = m['avatar_url']?.toString();
            _toast('group_settings_saved'.tr);
          },
          failure: showAppError,
        );
        state.saving.value = false;

      case RemoveGroupMember a:
        if (!_isAdmin) return;
        final ok = await _confirm(
          title: 'group_settings_remove_member'.tr,
          body: 'group_settings_remove_confirm'.tr,
          confirmLabel: 'group_settings_remove_member'.tr,
          danger: true,
        );
        if (!ok) return;
        final result = await repo.removeMember(state.chatId, a.userId);
        result.when(
          success: (_) => sendAction(ReloadMembers()),
          failure: showAppError,
        );

      case PromoteGroupAdmin a:
        if (!_isOwner) return;
        final result = await repo.promoteAdmin(state.chatId, a.userId);
        result.when(
          success: (_) => sendAction(ReloadMembers()),
          failure: showAppError,
        );

      case DemoteGroupAdmin a:
        if (!_isOwner) return;
        final result = await repo.demoteAdmin(state.chatId, a.userId);
        result.when(
          success: (_) => sendAction(ReloadMembers()),
          failure: showAppError,
        );

      case LeaveGroupAction _:
        final ok = await _confirm(
          title: 'group_settings_leave'.tr,
          body: 'group_settings_leave_confirm'.tr,
          confirmLabel: 'group_settings_leave_action'.tr,
          danger: true,
        );
        if (!ok) return;
        final result = await repo.leaveGroup(state.chatId);
        result.when(
          success: (_) {
            Navigator.of(context).popUntil((r) => r.isFirst);
          },
          failure: showAppError,
        );

      case TransferOwnershipAction a:
        if (!_isOwner) return;
        final ok = await _confirm(
          title: 'group_settings_transfer'.tr,
          body: 'group_settings_transfer_confirm'.tr,
          confirmLabel: 'group_settings_transfer_action'.tr,
          danger: true,
        );
        if (!ok) return;
        final result =
            await repo.transferOwnership(state.chatId, userId: a.userId);
        result.when(
          success: (_) {
            state.myRole.value = 'admin';
            sendAction(ReloadMembers());
            _toast('group_settings_saved'.tr);
          },
          failure: showAppError,
        );

      case DeleteGroupAction _:
        if (!_isOwner) return;
        final ok = await _confirm(
          title: 'group_settings_delete'.tr,
          body: 'group_settings_delete_confirm'.tr,
          danger: true,
        );
        if (!ok) return;
        final result = await repo.deleteGroup(state.chatId);
        result.when(
          success: (_) {
            Navigator.of(context).popUntil((r) => r.isFirst);
          },
          failure: showAppError,
        );

      case CopyInviteLink _:
        final link = state.inviteLink.value;
        if (link == null || link.isEmpty) return;
        await Clipboard.setData(ClipboardData(text: link));
        _toast('group_settings_invite_copied'.tr);

      case RegenerateInviteLink _:
        if (!_isAdmin) return;
        final result = await repo.regenerateInvite(state.chatId);
        result.when(
          success: (d) {
            final m = asMap(d) ?? {};
            state.inviteLink.value = m['link']?.toString();
            _toast('group_settings_invite_renewed'.tr);
          },
          failure: showAppError,
        );

      case DisableInviteLink _:
        if (!_isAdmin) return;
        final result = await repo.disableInvite(state.chatId);
        result.when(
          success: (_) {
            state.inviteLink.value = null;
            _toast('group_settings_invite_disabled'.tr);
          },
          failure: showAppError,
        );

      case UpgradeSuperGroup _:
        if (!_isOwner || state.isSuper.value) return;
        await _upgradeSuper();

      default:
        break;
    }
  }

  Future<void> _addMembers() async {
    final existing = state.members.map((m) => m.userId).toSet();
    final friendsResult =
        await Get.find<FriendsRepository>().listFriends(limit: 100);
    final friends = <Friend>[];
    friendsResult.when(
      success: (data) {
        friends.addAll(
          asList(data)
              .whereType<Map>()
              .map((e) => Friend.fromApi(Map<String, dynamic>.from(e)))
              .where((f) => !existing.contains(f.id)),
        );
      },
      failure: showAppError,
    );
    if (friends.isEmpty) {
      _toast('group_settings_no_friends_to_add'.tr);
      return;
    }
    if (!context.mounted) return;
    final selected = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddMembersSheet(friends: friends),
    );
    if (selected == null || selected.isEmpty) return;
    final result = await Get.find<ChatRepository>().addMembers(
      state.chatId,
      userIds: selected.toList(),
    );
    result.when(
      success: (_) {
        sendAction(ReloadMembers());
        _toast('group_settings_members_added'.tr);
      },
      failure: showAppError,
    );
  }

  Future<void> _upgradeSuper() async {
    final pay = Get.find<PaymentRepository>();
    final checkout = await pay.checkoutSuperGroup(chatId: state.chatId);
    final data = checkout.dataOrNull;
    if (data == null) {
      showAppError(checkout.errorOrNull);
      return;
    }
    final map = asMap(data) ?? {};
    final url = map['checkout_url']?.toString();
    final id = (map['id'] as num?)?.toInt();
    final mock = map['mock_confirm'] == true;
    if (url != null && url.isNotEmpty) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
    if (id == null) return;
    if (mock) {
      final conf = await pay.confirmMock(id);
      conf.when(
        success: (_) {
          state.isSuper.value = true;
          state.memberLimit.value = null;
          _toast('group_settings_super_ok'.tr);
        },
        failure: showAppError,
      );
      return;
    }
    for (var i = 0; i < 8; i++) {
      await Future.delayed(const Duration(seconds: 2));
      final st = await pay.getPayment(id);
      final p = asMap(st.dataOrNull) ?? {};
      if (p['status'] == 'succeeded') {
        state.isSuper.value = true;
        state.memberLimit.value = null;
        _toast('group_settings_super_ok'.tr);
        break;
      }
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    bool danger = false,
    String? confirmLabel,
  }) async {
    final choice = await showTelegramActionSheet(
      context,
      title: title,
      body: body,
      actions: [
        TelegramSheetAction(
          id: 'ok',
          label: confirmLabel ?? 'common_delete'.tr,
          danger: danger,
          primary: !danger,
        ),
      ],
    );
    return choice == 'ok';
  }
}

class _AddMembersSheet extends StatefulWidget {
  final List<Friend> friends;
  const _AddMembersSheet({required this.friends});

  @override
  State<_AddMembersSheet> createState() => _AddMembersSheetState();
}

class _AddMembersSheetState extends State<_AddMembersSheet> {
  final _selected = <int>{};

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
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
          Expanded(
            child: ListView.builder(
              itemCount: widget.friends.length,
              itemBuilder: (_, i) {
                final f = widget.friends[i];
                final on = _selected.contains(f.id);
                return CheckboxListTile(
                  value: on,
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selected.add(f.id);
                      } else {
                        _selected.remove(f.id);
                      }
                    });
                  },
                  title: Text(f.name),
                  controlAffinity: ListTileControlAffinity.trailing,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}