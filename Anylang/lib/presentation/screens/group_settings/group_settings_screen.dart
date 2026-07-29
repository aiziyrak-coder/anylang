import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/core/mappers.dart';
import '../../../data/network/chat_repository.dart';
import '../../../data/network/payment_repository.dart';
import '../../modal/add_group_members_bottom_sheet.dart';
import '../../modal/image_picker.dart';
import '../../modal/payment_confirm_bottom_sheet.dart';
import '../../modal/telegram_action_sheet.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/auth_validators.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import '../messages/conversation.dart';
import '../group_catalog/group_catalog_payload.dart';
import '../group_catalog/group_catalog_screen.dart';
import '../group_stats/group_stats_payload.dart';
import '../group_stats/group_stats_screen.dart';
import 'group_settings_action.dart';
import 'group_settings_content.dart';
import 'group_settings_payload.dart';
import 'group_settings_state.dart';

class GroupSettingsScreen extends Screen<GroupSettingsState, GroupSettingsPayload> {
  GroupSettingsScreen() : super(mobileContent: GroupSettingsContent());

  @override
  void initState(GroupSettingsPayload? payload) {
    final p = payload;
    if (p == null) {
      Future.microtask(() {
        showAppError('screen_payload_missing'.tr);
        popBackNavigate();
      });
      return;
    }
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

      case OpenGroupCatalogFromSettings _:
        await navigate(
          GroupCatalogScreen(),
          payload: GroupCatalogPayload(
            chatId: state.chatId,
            title: state.title.value,
          ),
        );

      case OpenGroupStatsFromSettings _:
        await navigate(
          GroupStatsScreen(),
          payload: GroupStatsPayload(
            chatId: state.chatId,
            title: state.title.value,
          ),
        );

      case ReloadMembers _:
        state.loading.value = true;
        try {
          final result = await repo.listMembers(state.chatId);
          final data = result.dataOrNull;
          if (data == null) {
            showAppError(result.errorOrNull);
            break;
          }
          final map = asMap(data);
          if (map == null) {
            showAppError('unknown_error'.tr);
            break;
          }
          final items = (map['items'] as List?) ?? const [];
          state.members.assignAll(
            items
                .whereType<Map>()
                .map((e) => GroupMemberVm.fromApi(Map<String, dynamic>.from(e))),
          );
          final inv = await repo.getInvite(state.chatId);
          inv.when(
            success: (d) {
              final m = asMap(d) ?? {};
              state.inviteLink.value = m['link']?.toString();
            },
            failure: showAppError,
          );
        } finally {
          state.loading.value = false;
        }

      case AddGroupMembers _:
        await _addMembers();
        break;

      case SaveGroupTitle a:
        if (!_isAdmin) return;
        final title = a.title.trim();
        if (title.isEmpty) {
          showAppError('group_settings_title_required'.tr);
          return;
        }
        state.saving.value = true;
        final result = await repo.updateGroup(chatId: state.chatId, title: title);
        result.when(
          success: (_) {
            state.title.value = title;
            showAppMessage('group_settings_saved'.tr);
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
            showAppMessage('group_settings_saved'.tr);
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
            showAppMessage('group_settings_saved'.tr);
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
        showAppMessage('group_settings_invite_copied'.tr);

      case RegenerateInviteLink _:
        if (!_isAdmin) return;
        final result = await repo.regenerateInvite(state.chatId);
        result.when(
          success: (d) {
            final m = asMap(d) ?? {};
            state.inviteLink.value = m['link']?.toString();
            showAppMessage('group_settings_invite_renewed'.tr);
          },
          failure: showAppError,
        );

      case DisableInviteLink _:
        if (!_isAdmin) return;
        final result = await repo.disableInvite(state.chatId);
        result.when(
          success: (_) {
            state.inviteLink.value = null;
            showAppMessage('group_settings_invite_disabled'.tr);
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
    final chatsResult = await Get.find<ChatRepository>().listChats(
      limit: 100,
      type: 'direct',
    );
    final candidates = <GroupMemberCandidate>[];
    var loadFailed = false;
    chatsResult.when(
      success: (data) {
        final list = asList(data);
        for (final raw in list) {
          if (raw is! Map) continue;
          final conv = Conversation.fromApi(Map<String, dynamic>.from(raw));
          if (conv.isGroup || conv.isMarketplace || conv.peerId <= 0) {
            continue;
          }
          candidates.add(
            GroupMemberCandidate.fromConversation(
              conv,
              alreadyInGroup: existing.contains(conv.peerId),
            ),
          );
        }
      },
      failure: (_) {
        loadFailed = true;
      },
    );
    if (loadFailed) {
      showAppError(AuthValidators.safeError(
        chatsResult.errorOrNull,
        fallbackKey: 'group_settings_chats_load_failed',
      ));
      return;
    }
    if (candidates.every((c) => c.alreadyInGroup)) {
      showAppMessage('group_settings_no_contacts_to_add'.tr);
      return;
    }
    if (!context.mounted) return;
    final selected = await showAddGroupMembersBottomSheet(
      context,
      candidates: candidates,
    );
    if (selected == null || selected.isEmpty) return;
    final result = await Get.find<ChatRepository>().addMembers(
      state.chatId,
      userIds: selected.toList(),
    );
    result.when(
      success: (_) {
        sendAction(ReloadMembers());
        showAppMessage('group_settings_members_added'.tr);
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
    final currency = (map['currency']?.toString() ?? 'UZS').toUpperCase();
    final amount = map['amount']?.toString() ?? '';
    final taxPctRaw = map['tax_percent'];
    final taxPct = taxPctRaw is num
        ? taxPctRaw.toInt()
        : int.tryParse('$taxPctRaw') ?? 2;

    final confirmed = await showPaymentConfirmBottomSheet(
      context,
      title: 'group_settings_super'.tr,
      subtitle: 'payment_confirm_subtitle'.tr,
      amount: amount,
      currency: currency,
      amountBeforeTax: map['amount_before_tax']?.toString(),
      taxAmount: map['tax_amount']?.toString(),
      taxPercent: taxPct,
      planLabel: 'group_settings_super_badge'.tr,
      ctaText: 'subscription_pay_confirm_cta'.tr,
    );
    if (confirmed != true) {
      showAppMessage('payment_confirm_later_hint'.tr);
      return;
    }

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
          showAppMessage('group_settings_super_ok'.tr);
        },
        failure: showAppError,
      );
      return;
    }
    var succeeded = false;
    for (var i = 0; i < 8; i++) {
      await Future.delayed(const Duration(seconds: 2));
      final st = await pay.getPayment(id);
      final p = asMap(st.dataOrNull) ?? {};
      if (p['status'] == 'succeeded') {
        state.isSuper.value = true;
        state.memberLimit.value = null;
        showAppMessage('group_settings_super_ok'.tr);
        succeeded = true;
        break;
      }
    }
    if (!succeeded) {
      showAppWarning('group_settings_payment_timeout'.tr);
    }
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