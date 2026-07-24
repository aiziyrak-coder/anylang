import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../ui/app_top_bar.dart';
import '../../ui/buttons/danger_button.dart';
import '../../ui/gradient_background.dart';
import '../../ui/profile_avatar.dart';
import '../../ui/theme/colors.dart';
import '../../ui/theme/gradients.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen_content.dart';
import '../../utils/size_controller.dart';
import 'group_settings_action.dart';
import 'group_settings_state.dart';

class GroupSettingsContent extends ScreenContent<GroupSettingsState> {
  final _titleCtrl = TextEditingController();

  @override
  void onClose() {
    _titleCtrl.dispose();
    super.onClose();
  }

  @override
  Widget build(
    BuildContext context,
    GroupSettingsState state,
    void Function(MyAction action) sendAction,
  ) {
    final c = context.appColors;
    return GradientBackground(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.dp, 4.dp, 16.dp, 0),
              child: AppTopBar(
                title: 'group_settings_title'.tr,
                onBack: () => sendAction(Back()),
              ),
            ),
            Expanded(
              child: Obx(() {
                if (state.loading.value && state.members.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                final role = state.myRole.value;
                final isAdmin = role == 'owner' || role == 'admin';
                final isOwner = role == 'owner';
                if (_titleCtrl.text != state.title.value &&
                    !_titleCtrl.selection.isValid) {
                  _titleCtrl.text = state.title.value;
                }
                return ListView(
                  padding: EdgeInsets.fromLTRB(16.dp, 12.dp, 16.dp, 24.dp),
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: isAdmin ? () => sendAction(PickGroupAvatar()) : null,
                        child: ProfileAvatar(
                          initial: state.title.value.isNotEmpty
                              ? state.title.value[0].toUpperCase()
                              : 'G',
                          gradient: avatarTealGradient,
                          size: 88,
                          imageUrl: state.avatarUrl.value,
                        ),
                      ),
                    ),
                    SizedBox(height: 12.dp),
                    if (isAdmin)
                      TextField(
                        controller: _titleCtrl,
                        decoration: InputDecoration(
                          labelText: 'group_settings_name'.tr,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.check),
                            onPressed: () =>
                                sendAction(SaveGroupTitle(_titleCtrl.text)),
                          ),
                        ),
                      )
                    else
                      Text(
                        state.title.value,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                      ),
                    if (state.isSuper.value) ...[
                      SizedBox(height: 8.dp),
                      Center(
                        child: Text(
                          'group_settings_super_badge'.tr,
                          style: TextStyle(
                            color: c.accentText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: 8.dp),
                    Text(
                      '${state.members.length}'
                      '${state.memberLimit.value != null ? ' / ${state.memberLimit.value}' : ''}'
                      ' ${'group_settings_members'.tr}',
                      style: TextStyle(color: c.textSecondary, fontSize: 13.sp),
                    ),
                    SizedBox(height: 16.dp),
                    if (isAdmin) ...[
                      Text(
                        'group_settings_invite'.tr,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                      ),
                      SizedBox(height: 8.dp),
                      if ((state.inviteLink.value ?? '').isNotEmpty)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            state.inviteLink.value!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13.sp, color: c.textSecondary),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () => sendAction(CopyInviteLink()),
                          ),
                        ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => sendAction(RegenerateInviteLink()),
                            child: Text('group_settings_invite_renew'.tr),
                          ),
                          TextButton(
                            onPressed: () => sendAction(DisableInviteLink()),
                            child: Text('group_settings_invite_disable'.tr),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.dp),
                    ],
                    if (isOwner && !state.isSuper.value) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.star_outline, color: c.accentText),
                        title: Text('group_settings_super'.tr),
                        subtitle: Text('group_settings_super_desc'.tr),
                        trailing: TextButton(
                          onPressed: () => sendAction(UpgradeSuperGroup()),
                          child: Text(r'$10'),
                        ),
                      ),
                      SizedBox(height: 8.dp),
                    ],
                    Text(
                      'group_settings_members'.tr,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                    SizedBox(height: 8.dp),
                    for (final m in state.members)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ProfileAvatar(
                          initial: m.fullName.isNotEmpty
                              ? m.fullName[0].toUpperCase()
                              : '?',
                          gradient: avatarTealGradient,
                          size: 40,
                          imageUrl: m.avatarUrl,
                        ),
                        title: Text(m.fullName),
                        subtitle: Text(_roleLabel(m.role)),
                        trailing: isAdmin && m.role != 'owner'
                            ? PopupMenuButton<String>(
                                onSelected: (v) {
                                  switch (v) {
                                    case 'remove':
                                      sendAction(RemoveGroupMember(m.userId));
                                    case 'promote':
                                      sendAction(PromoteGroupAdmin(m.userId));
                                    case 'demote':
                                      sendAction(DemoteGroupAdmin(m.userId));
                                    case 'transfer':
                                      sendAction(
                                        TransferOwnershipAction(m.userId),
                                      );
                                  }
                                },
                                itemBuilder: (_) => [
                                  if (isOwner && m.role == 'member')
                                    PopupMenuItem(
                                      value: 'promote',
                                      child: Text('group_settings_promote'.tr),
                                    ),
                                  if (isOwner && m.role == 'admin')
                                    PopupMenuItem(
                                      value: 'demote',
                                      child: Text('group_settings_demote'.tr),
                                    ),
                                  if (isOwner)
                                    PopupMenuItem(
                                      value: 'transfer',
                                      child: Text('group_settings_transfer'.tr),
                                    ),
                                  PopupMenuItem(
                                    value: 'remove',
                                    child: Text('group_settings_remove_member'.tr),
                                  ),
                                ],
                              )
                            : null,
                      ),
                    SizedBox(height: 20.dp),
                    if (!isOwner)
                      DangerButton(
                        text: 'group_settings_leave'.tr,
                        onTap: () => sendAction(LeaveGroupAction()),
                      ),
                    if (isOwner)
                      DangerButton(
                        text: 'group_settings_delete'.tr,
                        onTap: () => sendAction(DeleteGroupAction()),
                      ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  String _roleLabel(String role) {
    return switch (role) {
      'owner' => 'group_settings_role_owner'.tr,
      'admin' => 'group_settings_role_admin'.tr,
      _ => 'group_settings_role_member'.tr,
    };
  }
}
