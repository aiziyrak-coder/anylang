import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/core/mappers.dart';
import '../../../data/network/chat_repository.dart';
import '../../../data/network/payment_repository.dart';
import '../../modal/image_picker.dart';
import '../../modal/telegram_action_sheet.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
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
            if (_isAdmin) {
              repo.getInvite(state.chatId).then((inv) {
                inv.when(
                  success: (d) {
                    final m = asMap(d) ?? {};
                    state.inviteLink.value = m['link']?.toString();
                  },
                  failure: (_) {},
                );
              });
            }
          },
          failure: showAppError,
        );
        state.loading.value = false;

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